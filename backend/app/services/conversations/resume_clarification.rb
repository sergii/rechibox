module Conversations
  class ResumeClarification
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

      if answered.fetch("status") == "none_of_above"
        turn = update_turn(context, status: "completed", clarification: answered, proposals: [])
        return {
          "conversation" => conversation,
          "conversation_status" => turn ? turn.fetch("status") : "completed",
          "turn" => turn,
          "clarification" => answered,
          "state_update_proposal_mode" => @state_update_proposer.mode,
          "state_update_proposals" => []
        }.compact
      end

      world = @world_store.fetch(world_id)
      situation = context.fetch("situation")
      resolution = resolved_resolution(context: context, clarification: answered)
      proposal_result = WorldState::ProposeUpdates.new(
        world_id: world_id,
        situation: situation.merge("entity_resolutions" => resolution.fetch("resolutions")),
        proposer: @state_update_proposer,
        store: @world_store,
        conversation_id: @conversation_id,
        message_id: context.fetch("message_id"),
        turn_id: context["turn_id"]
      ).call
      proposals = proposal_result.fetch("proposals")
      turn_status = proposals.any? ? "ready_for_review" : "completed"
      turn = update_turn(context, status: turn_status, clarification: answered, proposals: proposals)

      {
        "conversation" => conversation,
        "conversation_status" => turn ? turn.fetch("status") : turn_status,
        "turn" => turn,
        "clarification" => answered,
        "world_state" => world,
        "entity_resolution" => resolution,
        "state_update_proposal_mode" => proposal_result.fetch("mode"),
        "state_update_proposals" => proposals
      }.compact
    end

    private

    def update_turn(context, status:, clarification:, proposals:)
      turn_id = context["turn_id"]
      return unless turn_id

      @turn_store.update(conversation_id: @conversation_id, id: turn_id) do |record|
        record["status"] = status
        record["resolved_clarification_ids"] ||= []
        record["resolved_clarification_ids"] << clarification.fetch("id") unless record["resolved_clarification_ids"].include?(clarification.fetch("id"))
        record["proposal_ids"] = proposals.map { |row| row.fetch("id") }
        record["completed_at"] = Time.now.utc.iso8601(6) if status == "completed"
      end
    end

    def resolved_resolution(context:, clarification:)
      original = context.fetch("entity_resolution")
      target_ref = clarification.fetch("situation_entity_ref")
      selected_id = clarification.fetch("selected_entity_id")

      rows = Array(original.fetch("resolutions")).map do |row|
        next row unless row.fetch("situation_entity_ref") == target_ref

        row.merge(
          "status" => "resolved",
          "durable_entity_id" => selected_id,
          "resolved_by" => {
            "type" => "clarification",
            "clarification_id" => clarification.fetch("id")
          }
        )
      end

      original.merge("resolutions" => rows)
    end
  end
end
