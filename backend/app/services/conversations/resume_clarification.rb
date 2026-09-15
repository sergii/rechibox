module Conversations
  class ResumeClarification
    TERMINAL_CLARIFICATION_STATUSES = %w[resolved none_of_above].freeze
    FINAL_TURN_STATUSES = %w[ready_for_review completed].freeze

    def initialize(
      conversation_id:,
      clarification_id:,
      action:,
      option_id: nil,
      store: Store.default,
      world_store: WorldState::Store.default,
      clarification_store: WorldState::ClarificationStore.default,
      state_update_proposer: Ai::StateUpdateProposer.default,
      turn_store: TurnStore.default,
      proposal_store: WorldState::ProposalStore.default
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
      @proposal_store = proposal_store
    end

    def call
      conversation = @store.fetch(@conversation_id)
      world_id = conversation.fetch("world_id")
      clarification = @clarification_store.fetch(world_id: world_id, id: @clarification_id)
      context = resume_context!(clarification)

      return resume_legacy_clarification(conversation: conversation, world_id: world_id, context: context) unless context["turn_id"]

      stage = stage_turn_resume(
        conversation: conversation,
        world_id: world_id,
        turn_id: context.fetch("turn_id")
      )
      return stage.fetch(:response) if stage[:response]

      finalize_with_proposals(
        conversation: conversation,
        world_id: world_id,
        stage: stage
      )
    end

    private

    # Phase one is intentionally short. It serializes sibling clarification
    # answers on the turn row, persists the answer, and decides whether the
    # barrier is closed. It never calls a model provider.
    def stage_turn_resume(conversation:, world_id:, turn_id:)
      stage = nil

      Persistence.transaction do
        @turn_store.update(conversation_id: @conversation_id, id: turn_id) do |turn|
          clarification = @clarification_store.fetch(world_id: world_id, id: @clarification_id)
          context = resume_context!(clarification)
          raise ArgumentError, "clarification belongs to another conversation turn" unless context.fetch("turn_id") == turn.fetch("id")

          clarification_ids = Array(turn["clarification_ids"])
          raise ArgumentError, "clarification is not linked to conversation turn" unless clarification_ids.include?(@clarification_id)

          answered = answer_or_reuse_clarification(world_id: world_id, clarification: clarification)

          if FINAL_TURN_STATUSES.include?(turn.fetch("status"))
            stage = {
              response: finalized_turn_response(
                conversation: conversation,
                world_id: world_id,
                turn: turn,
                answered: answered
              )
            }
            next
          end

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
            stage = {
              response: clarification_barrier_response(
                conversation: conversation,
                turn: turn,
                answered: answered,
                pending: pending
              )
            }
            next
          end

          if clarifications.any? { |row| row.fetch("status") == "none_of_above" }
            apply_turn_update!(
              turn: turn,
              status: "completed",
              clarification: answered,
              proposals: []
            )
            stage = {
              response: {
                "conversation" => conversation,
                "conversation_status" => turn.fetch("status"),
                "turn" => turn,
                "clarification" => answered,
                "pending_clarification_ids" => [],
                "state_update_proposal_mode" => @state_update_proposer.mode,
                "state_update_proposals" => []
              }
            }
            next
          end

          apply_turn_update!(
            turn: turn,
            status: "awaiting_clarification",
            clarification: answered,
            proposals: nil
          )
          stage = {
            context: context,
            answered: answered,
            clarifications: clarifications,
            turn_id: turn.fetch("id")
          }
        end
      end

      stage
    end

    # Phase two computes proposal candidates without holding a database lock.
    # With the default disabled proposer this remains model-free. If RubyLLM is
    # explicitly enabled, provider latency happens here, outside the transaction.
    def finalize_with_proposals(conversation:, world_id:, stage:)
      context = stage.fetch(:context)
      resolution = resolved_resolution_set(
        original: context.fetch("entity_resolution"),
        clarifications: stage.fetch(:clarifications)
      )
      situation = context.fetch("situation").merge(
        "entity_resolutions" => resolution.fetch("resolutions")
      )
      proposal_service = WorldState::ProposeUpdates.new(
        world_id: world_id,
        situation: situation,
        proposer: @state_update_proposer,
        store: @world_store,
        proposal_store: @proposal_store,
        conversation_id: @conversation_id,
        message_id: context.fetch("message_id"),
        turn_id: stage.fetch(:turn_id)
      )
      prepared = proposal_service.prepare
      world = @world_store.fetch(world_id)
      response = nil

      Persistence.transaction do
        @turn_store.update(conversation_id: @conversation_id, id: stage.fetch(:turn_id)) do |turn|
          if FINAL_TURN_STATUSES.include?(turn.fetch("status"))
            response = finalized_turn_response(
              conversation: conversation,
              world_id: world_id,
              turn: turn,
              answered: stage.fetch(:answered)
            )
            next
          end

          raise ArgumentError, "conversation turn is no longer awaiting clarification finalization" unless turn.fetch("status") == "awaiting_clarification"

          persisted = proposal_service.persist(prepared: prepared)
          proposals = persisted.fetch("proposals")
          turn_status = proposals.any? ? "ready_for_review" : "completed"
          apply_turn_update!(
            turn: turn,
            status: turn_status,
            clarification: stage.fetch(:answered),
            proposals: proposals
          )

          response = {
            "conversation" => conversation,
            "conversation_status" => turn.fetch("status"),
            "turn" => turn,
            "clarification" => stage.fetch(:answered),
            "pending_clarification_ids" => [],
            "world_state" => world,
            "entity_resolution" => resolution,
            "state_update_proposal_mode" => persisted.fetch("mode"),
            "state_update_proposals" => proposals
          }
        end
      end

      response
    end

    def finalized_turn_response(conversation:, world_id:, turn:, answered:)
      proposals = Array(turn["proposal_ids"]).map do |id|
        @proposal_store.fetch(world_id: world_id, id: id)
      end

      {
        "conversation" => conversation,
        "conversation_status" => turn.fetch("status"),
        "turn" => turn,
        "clarification" => answered,
        "pending_clarification_ids" => [],
        "state_update_proposal_mode" => @state_update_proposer.mode,
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

    def answer_or_reuse_clarification(world_id:, clarification:)
      return answer_clarification(world_id: world_id) if clarification.fetch("status") == "pending"

      unless clarification_retry_matches?(clarification)
        raise ArgumentError, "clarification is already closed with a different answer"
      end

      clarification
    end

    def clarification_retry_matches?(clarification)
      case clarification.fetch("status")
      when "resolved"
        @action == "select" && clarification.fetch("selected_option_id") == @option_id.to_s
      when "none_of_above"
        @action == "none_of_above"
      else
        false
      end
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
        proposal_store: @proposal_store,
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
