module Conversations
  class ResumeClarification
    TERMINAL_CLARIFICATION_STATUSES = %w[resolved none_of_above].freeze

    def initialize(
      conversation_id:,
      clarification_id:,
      action:,
      option_id: nil,
      store: Store.default,
      world_store: WorldState::Store.default,
      clarification_store: WorldState::ClarificationStore.default,
      state_update_proposer: Ai::StateUpdateProposer.default,
      turn_store: TurnStore.default
    )
      @conversation_id = conversation_id
      @clarification_id = clarification_id
      @action = action.to_s
      @option_id = option_id
      @store = store
      @world_store = world_store
      @clarification_store = clarification_store
      @state_update_proposer = state_update_proposer
      @turn_store = turn_store
    end

    def call
      conversation = @store.fetch(@conversation_id)
      world_id = conversation.fetch("world_id")
      clarification = @clarification_store.fetch(world_id: world_id, id: @clarification_id)
      context = resume_context!(clarification)

      return resume_legacy_clarification(conversation: conversation, world_id: world_id, context: context) unless context["turn_id"]

      resume_transactional_turn(conversation: conversation, world_id: world_id, turn_id: context.fetch("turn_id"))
    end

    private

    def resume_transactional_turn(conversation:, world_id:, turn_id:)
      result = nil

      Persistence.transaction do
        # The turn row is the serialization point for every clarification answer
        # that belongs to this turn. ActiveRecord keeps this row lock until the
        # outer transaction commits, so sibling answers cannot both observe each
        # other as pending and leave the turn stuck behind the barrier.
        @turn_store.update(conversation_id: @conversation_id, id: turn_id) do |turn|
          clarification = @clarification_store.fetch(world_id: world_id, id: @clarification_id)
          context = resume_context!(clarification)
          raise ArgumentError, "clarification belongs to another conversation turn" unless context.fetch("turn_id") == turn.fetch("id")

          answered = answer_clarification(world_id: world_id)
          result = resume_locked_turn(
            conversation: conversation,
            world_id: world_id,
            context: context,
            answered: answered,
            turn: turn
          )
        end
      end

      result
    end

    def resume_locked_turn(conversation:, world_id:, context:, answered:, turn:)
      clarification_ids = Array(turn["clarification_ids"])
      raise ArgumentError, "clarification is not linked to conversation turn" unless clarification_ids.include?(@clarification_id)

      clarifications = clarification_ids.map do |id|
        @clarification_store.fetch(world_id: world_id, id: id)
      end
      pending = clarifications.reject { |row| TERMINAL_CLARIFICATION_STATUSES.include?(row.fetch("status")) }

      if pending.any?
        apply_turn_update!(
          turn: turn,
          status: "awaiting_clarification",
          clarification: answered,
          proposals: nil
        )
        return clarification_barrier_response(
          conversation: conversation,
          turn: turn,
          answered: answered,
          pending: pending
        )
      end

      if clarifications.any? { |row| row.fetch("status") == "none_of_above" }
        apply_turn_update!(
          turn: turn,
          status: "completed",
          clarification: answered,
          proposals: []
        )
        return {
          "conversation" => conversation,
          "conversation_status" => turn.fetch("status"),
          "turn" => turn,
          "clarification" => answered,
          "pending_clarification_ids" => [],
          "state_update_proposal_mode" => @state_update_proposer.mode,
          "state_update_proposals" => []
        }
      end

      world = @world_store.fetch(world_id)
      situation = context.fetch("situation")
      resolution = resolved_resolution_set(
        original: context.fetch("entity_resolution"),
        clarifications: clarifications
      )
      proposal_result = WorldState::ProposeUpdates.new(
        world_id: world_id,
        situation: situation.merge("entity_resolutions" => resolution.fetch("resolutions")),
        proposer: @state_update_proposer,
        store: @world_store,
        conversation_id: @conversation_id,
        message_id: context.fetch("message_id"),
        turn_id: turn.fetch("id")
      ).call
      proposals = proposal_result.fetch("proposals")
      turn_status = proposals.any? ? "ready_for_review" : "completed"
      apply_turn_update!(
        turn: turn,
        status: turn_status,
        clarification: answered,
        proposals: proposals
      )

      {
        "conversation" => conversation,
        "conversation_status" => turn.fetch("status"),
        "turn" => turn,
        "clarification" => answered,
        "pending_clarification_ids" => [],
        "world_state" => world,
        "entity_resolution" => resolution,
        "state_update_proposal_mode" => proposal_result.fetch("mode"),
        "state_update_proposals" => proposals
      }
    end

    def clarification_barrier_response(conversation:, turn:, answered:, pending:)
      {
        "conversation" => conversation,
        "conversation_status" => turn.fetch("status"),
        "turn" => turn,
        "clarification" => answered,
        "pending_clarification_ids" => pending.map { |row| row.fetch("id") },
        "state_update_proposal_mode" => @state_update_proposer.mode,
        "state_update_proposals" => []
      }
    end

    def apply_turn_update!(turn:, status:, clarification:, proposals:)
      TurnState.transition!(turn, to: status)
      turn["resolved_clarification_ids"] ||= []
      turn["resolved_clarification_ids"] << clarification.fetch("id") unless turn["resolved_clarification_ids"].include?(clarification.fetch("id"))
      turn["proposal_ids"] = proposals.map { |row| row.fetch("id") } unless proposals.nil?
      turn
    end

    def resume_context!(clarification)
      context = clarification.fetch("resume_context") do
        raise ArgumentError, "clarification cannot resume a conversation"
      end
      raise ArgumentError, "clarification belongs to another conversation" unless context.fetch("conversation_id") == @conversation_id

      context
    end

    def answer_clarification(world_id:)
      WorldState::AnswerClarification.new(
        world_id: world_id,
        clarification_id: @clarification_id,
        action: @action,
        option_id: @option_id,
        store: @clarification_store,
        world_store: @world_store
      ).call
    end

    def resolved_resolution_set(original:, clarifications:)
      selections = clarifications.to_h do |clarification|
        [clarification.fetch("situation_entity_ref"), clarification]
      end

      rows = Array(original.fetch("resolutions")).map do |row|
        clarification = selections[row.fetch("situation_entity_ref")]
        next row unless clarification

        row.merge(
          "status" => "resolved",
          "durable_entity_id" => clarification.fetch("selected_entity_id"),
          "resolved_by" => {
            "type" => "clarification",
            "clarification_id" => clarification.fetch("id")
          }
        )
      end

      original.merge("resolutions" => rows)
    end

    def resume_legacy_clarification(conversation:, world_id:, context:)
      answered = answer_clarification(world_id: world_id)
      resume_legacy(
        conversation: conversation,
        world_id: world_id,
        context: context,
        answered: answered
      )
    end

    def resume_legacy(conversation:, world_id:, context:, answered:)
      if answered.fetch("status") == "none_of_above"
        return {
          "conversation" => conversation,
          "conversation_status" => "clarification_unresolved",
          "clarification" => answered,
          "state_update_proposal_mode" => @state_update_proposer.mode,
          "state_update_proposals" => []
        }
      end

      world = @world_store.fetch(world_id)
      situation = context.fetch("situation")
      resolution = resolved_resolution_set(
        original: context.fetch("entity_resolution"),
        clarifications: [answered]
      )
      proposal_result = WorldState::ProposeUpdates.new(
        world_id: world_id,
        situation: situation.merge("entity_resolutions" => resolution.fetch("resolutions")),
        proposer: @state_update_proposer,
        store: @world_store,
        conversation_id: @conversation_id,
        message_id: context.fetch("message_id"),
        turn_id: nil
      ).call

      {
        "conversation" => conversation,
        "conversation_status" => "resumed",
        "clarification" => answered,
        "world_state" => world,
        "entity_resolution" => resolution,
        "state_update_proposal_mode" => proposal_result.fetch("mode"),
        "state_update_proposals" => proposal_result.fetch("proposals")
      }
    end
  end
end
