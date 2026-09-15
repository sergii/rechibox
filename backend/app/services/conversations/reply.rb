require "securerandom"
require "time"

module Conversations
  class Reply
    def initialize(
      conversation_id:,
      message:,
      limit: nil,
      store: Store.default,
      world_store: WorldState::Store.default,
      state_update_proposer: Ai::StateUpdateProposer.default,
      clarification_store: WorldState::ClarificationStore.default,
      turn_store: TurnStore.default
    )
      @conversation_id = conversation_id
      @message = message.to_s.strip
      @limit = limit
      @store = store
      @world_store = world_store
      @state_update_proposer = state_update_proposer
      @clarification_store = clarification_store
      @turn_store = turn_store
    end

    def call
      raise ArgumentError, "message must not be blank" if @message.empty?

      conversation = @store.fetch(@conversation_id)
      world = @world_store.fetch(conversation.fetch("world_id"))
      history = conversation.fetch("messages").map do |message|
        {
          "role" => message.fetch("role"),
          "text" => message.fetch("text")
        }
      end

      user_message = build_message(role: "user", text: @message)
      turn = @turn_store.create(conversation_id: @conversation_id, message_id: user_message.fetch("id"))

      advice = Advice::Generate.new(
        message: @message,
        history: history,
        world_state: world,
        limit: @limit
      ).call

      entity_resolution = WorldState::ResolveEntities.new(
        world: world,
        situation: advice.fetch("situation")
      ).call

      updated_world = WorldState::ProjectSituation.new(
        world_id: world.fetch("id"),
        situation: advice.fetch("situation"),
        conversation_id: @conversation_id,
        message_id: user_message.fetch("id"),
        entity_resolutions: entity_resolution,
        store: @world_store
      ).call

      clarifications = WorldState::BuildClarifications.new(
        world_id: world.fetch("id"),
        resolution: entity_resolution,
        conversation_id: @conversation_id,
        message_id: user_message.fetch("id"),
        turn_id: turn.fetch("id"),
        situation: advice.fetch("situation"),
        store: @clarification_store
      ).call

      proposal_result = if clarifications.empty?
        WorldState::ProposeUpdates.new(
          world_id: world.fetch("id"),
          situation: advice.fetch("situation").merge(
            "entity_resolutions" => entity_resolution.fetch("resolutions")
          ),
          proposer: @state_update_proposer,
          store: @world_store,
          conversation_id: @conversation_id,
          message_id: user_message.fetch("id"),
          turn_id: turn.fetch("id")
        ).call
      else
        {
          "mode" => @state_update_proposer.mode,
          "world_id" => world.fetch("id"),
          "proposals" => [],
          "usage" => @state_update_proposer.usage
        }
      end

      new_messages = [user_message]
      if advice["answer"]
        new_messages << build_message(
          role: "assistant",
          text: advice.fetch("answer"),
          trace_id: advice["trace_id"]
        )
      end

      updated = @store.append(id: @conversation_id, messages: new_messages)
      turn = finalize_turn(
        turn: turn,
        clarifications: clarifications,
        proposals: proposal_result.fetch("proposals"),
        trace_id: advice["trace_id"]
      )

      {
        "conversation" => updated,
        "conversation_status" => turn.fetch("status"),
        "turn" => turn,
        "world_state" => updated_world,
        "entity_resolution" => entity_resolution,
        "identity_clarifications" => clarifications,
        "advice" => advice,
        "state_update_proposal_mode" => proposal_result.fetch("mode"),
        "state_update_proposals" => proposal_result.fetch("proposals")
      }
    rescue StandardError => e
      mark_failed_turn(turn, e) if defined?(turn) && turn
      raise
    end

    private

    def finalize_turn(turn:, clarifications:, proposals:, trace_id:)
      @turn_store.update(conversation_id: @conversation_id, id: turn.fetch("id")) do |record|
        record["status"] = if clarifications.any?
          "awaiting_clarification"
        elsif proposals.any?
          "ready_for_review"
        else
          "completed"
        end
        record["clarification_ids"] = clarifications.map { |row| row.fetch("id") }
        record["proposal_ids"] = proposals.map { |row| row.fetch("id") }
        record["trace_id"] = trace_id if trace_id
        record["completed_at"] = Time.now.utc.iso8601(6) if record["status"] == "completed"
      end
    end

    def mark_failed_turn(turn, error)
      @turn_store.update(conversation_id: @conversation_id, id: turn.fetch("id")) do |record|
        record["status"] = "failed"
        record["error"] = { "class" => error.class.name, "message" => error.message }
        record["failed_at"] = Time.now.utc.iso8601(6)
      end
    rescue StandardError
      nil
    end

    def build_message(role:, text:, trace_id: nil)
      {
        "id" => SecureRandom.uuid,
        "role" => role,
        "text" => text,
        "created_at" => Time.now.utc.iso8601(6),
        "trace_id" => trace_id
      }
    end
  end
end
