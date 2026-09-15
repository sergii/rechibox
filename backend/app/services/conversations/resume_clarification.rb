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
      context = clarification.fetch("resume_context") do
        raise ArgumentError, "clarification cannot resume a conversation"
      end
      raise ArgumentError, "clarification belongs to another conversation" unless context.fetch("conversation_id") == @conversation_id

      answered = WorldState::AnswerClarification.new(
        world_id: world_id,
        clarification_id: @clarification_id,
        action: @action,
        option_id: @option_id,
        store: @clarification_store,
        world_store: @world_store
      ).call

      return resume_legacy(conversation: conversation, world_id: world_id, context: context, answered: answered) unless context["turn_id"]

      resume_turn(conversation: conversation, world_id: world_id, context: context, answered: answered)
    end

    private

    def resume_turn(conversation:, world_id:, context:, answered:)
      turn = @turn_store.fetch(conversation_id: @conversation_id, id: context.fetch("turn_id"))
      clarification_ids = Array(turn["clarification_ids"])
      raise ArgumentError, "clarification is not linked to conversation turn" unless clarification_ids.include?(@clarification_id)

      clarifications = clarification_ids.map do |id|
        @clarification_store.fetch(world_id: world_id, id: id)
      end
      pending = clarifications.reject { |row| TERMINAL_CLARIFICATION_STATUSES.include?(row.fetch("status")) }

      if pending.any?
        turn = update_turn(
          turn_id: turn.fetch("id"),
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
        turn = update_turn(
          turn_id: turn.fetch("id"),
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
      turn = update_turn(
        turn_id: turn.fetch("id"),
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

    def update_turn(turn_id:, status:, clarification:, proposals:)
      @turn_store.update(conversation_id: @conversation_id, id: turn_id) do |record|
        TurnState.transition!(record, to: status)
        record["resolved_clarification_ids"] ||= []
        record["resolved_clarification_ids"] << clarification.fetch("id") unless record["resolved_clarification_ids"].include?(clarification.fetch("id"))
        record["proposal_ids"] = proposals.map { |row| row.fetch("id") } unless proposals.nil?
      end
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
