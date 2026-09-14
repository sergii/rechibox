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
      clarification_store: WorldState::ClarificationStore.default
    )
      @conversation_id = conversation_id
      @message = message.to_s.strip
      @limit = limit
      @store = store
      @world_store = world_store
      @state_update_proposer = state_update_proposer
      @clarification_store = clarification_store
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

      clarifications = WorldState::BuildClarifications.new(
        world_id: world.fetch("id"),
        resolution: entity_resolution,
        store: @clarification_store
      ).call

      updated_world = WorldState::ProjectSituation.new(
        world_id: world.fetch("id"),
        situation: advice.fetch("situation"),
        conversation_id: @conversation_id,
        message_id: user_message.fetch("id"),
        entity_resolutions: entity_resolution,
        store: @world_store
      ).call

      proposal_situation = advice.fetch("situation").merge(
        "entity_resolutions" => entity_resolution.fetch("resolutions")
      )
      proposals = @state_update_proposer.call(
        situation: proposal_situation,
        world_state: updated_world
      )

      new_messages = [user_message]
      if advice["answer"]
        new_messages << build_message(
          role: "assistant",
          text: advice.fetch("answer"),
          trace_id: advice["trace_id"]
        )
      end

      updated = @store.append(id: @conversation_id, messages: new_messages)

      {
        "conversation" => updated,
        "world_state" => updated_world,
        "entity_resolution" => entity_resolution,
        "identity_clarifications" => clarifications,
        "advice" => advice,
        "state_update_proposal_mode" => @state_update_proposer.mode,
        "state_update_proposals" => proposals
      }
    end

    private

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
