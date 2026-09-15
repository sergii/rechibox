require "test_helper"

class ConversationsAtomicClarificationResumeTest < ActiveSupport::TestCase
  class ExplodingProposer < Ai::StateUpdateProposer
    def mode
      "test"
    end

    def call(situation:, world_state:)
      raise "proposal generation failed"
    end
  end

  test "rolls back clarification and turn when final resume fails" do
    world_store = WorldState::Stores::ActiveRecord.new
    conversation_store = Conversations::Stores::ActiveRecord.new
    clarification_store = WorldState::ClarificationStores::ActiveRecord.new
    turn_store = Conversations::TurnStores::ActiveRecord.new

    world = world_store.create
    blue_id = SecureRandom.uuid
    red_id = SecureRandom.uuid
    world_store.update(id: world.fetch("id")) do |record|
      record.fetch("entities") << { "id" => blue_id, "kind" => "container", "label" => "blue box", "attributes" => {} }
      record.fetch("entities") << { "id" => red_id, "kind" => "container", "label" => "red box", "attributes" => {} }
    end

    conversation = conversation_store.create(world_id: world.fetch("id"))
    message_id = SecureRandom.uuid
    turn = turn_store.create(conversation_id: conversation.fetch("id"), message_id: message_id)
    situation = {
      "contract_version" => "0.1",
      "raw_input" => "Move the box.",
      "facts" => [],
      "goals" => [],
      "constraints" => [],
      "uncertainties" => [],
      "hypotheses" => [],
      "entities" => [{ "ref" => "E1", "kind" => "container", "label" => "box", "attributes" => {} }]
    }
    resolution = {
      "contract_version" => "0.1",
      "world_id" => world.fetch("id"),
      "resolutions" => [
        {
          "situation_entity_ref" => "E1",
          "kind" => "container",
          "label" => "box",
          "status" => "ambiguous",
          "durable_entity_id" => nil,
          "candidates" => [
            { "entity_id" => blue_id, "label" => "blue box", "kind" => "container", "score" => 0.5, "match" => "token_overlap" },
            { "entity_id" => red_id, "label" => "red box", "kind" => "container", "score" => 0.5, "match" => "token_overlap" }
          ]
        }
      ]
    }
    clarification = WorldState::BuildClarifications.new(
      world_id: world.fetch("id"),
      resolution: resolution,
      conversation_id: conversation.fetch("id"),
      message_id: message_id,
      turn_id: turn.fetch("id"),
      situation: situation,
      store: clarification_store
    ).call.fetch(0)

    turn_store.update(conversation_id: conversation.fetch("id"), id: turn.fetch("id")) do |record|
      Conversations::TurnState.transition!(record, to: "awaiting_clarification")
      record["clarification_ids"] = [clarification.fetch("id")]
    end

    error = assert_raises(RuntimeError) do
      Conversations::ResumeClarification.new(
        conversation_id: conversation.fetch("id"),
        clarification_id: clarification.fetch("id"),
        action: "select",
        option_id: "1",
        store: conversation_store,
        world_store: world_store,
        clarification_store: clarification_store,
        state_update_proposer: ExplodingProposer.new,
        turn_store: turn_store
      ).call
    end
    assert_equal "proposal generation failed", error.message

    persisted_clarification = clarification_store.fetch(world_id: world.fetch("id"), id: clarification.fetch("id"))
    persisted_turn = turn_store.fetch(conversation_id: conversation.fetch("id"), id: turn.fetch("id"))

    assert_equal "pending", persisted_clarification.fetch("status")
    assert_equal "awaiting_clarification", persisted_turn.fetch("status")
    assert_nil persisted_turn["resolved_clarification_ids"]
    assert_nil persisted_turn["proposal_ids"]
  end
end
