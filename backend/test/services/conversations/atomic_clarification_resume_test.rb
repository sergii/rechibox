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

  class EmptyProposer < Ai::StateUpdateProposer
    attr_reader :calls

    def initialize
      @calls = 0
    end

    def mode
      "test"
    end

    def call(situation:, world_state:)
      @calls += 1
      []
    end
  end

  test "commits the clarification before proposal computation and can retry finalization" do
    setup = build_active_record_turn

    error = assert_raises(RuntimeError) do
      resume(setup: setup, proposer: ExplodingProposer.new, option_id: "1")
    end
    assert_equal "proposal generation failed", error.message

    persisted_clarification = setup.fetch(:clarification_store).fetch(
      world_id: setup.dig(:world, "id"),
      id: setup.dig(:clarification, "id")
    )
    persisted_turn = setup.fetch(:turn_store).fetch(
      conversation_id: setup.dig(:conversation, "id"),
      id: setup.dig(:turn, "id")
    )

    assert_equal "resolved", persisted_clarification.fetch("status")
    assert_equal "1", persisted_clarification.fetch("selected_option_id")
    assert_equal "awaiting_clarification", persisted_turn.fetch("status")
    assert_equal [setup.dig(:clarification, "id")], persisted_turn.fetch("resolved_clarification_ids")
    assert_nil persisted_turn["proposal_ids"]

    proposer = EmptyProposer.new
    result = resume(setup: setup, proposer: proposer, option_id: "1")

    assert_equal "completed", result.fetch("conversation_status")
    assert_equal 1, proposer.calls
    assert_empty result.fetch("state_update_proposals")
  end

  test "rejects a retry that changes an already persisted clarification answer" do
    setup = build_active_record_turn

    assert_raises(RuntimeError) do
      resume(setup: setup, proposer: ExplodingProposer.new, option_id: "1")
    end

    error = assert_raises(ArgumentError) do
      resume(setup: setup, proposer: EmptyProposer.new, option_id: "2")
    end

    assert_equal "clarification is already closed with a different answer", error.message
  end

  private

  def resume(setup:, proposer:, option_id:)
    Conversations::ResumeClarification.new(
      conversation_id: setup.dig(:conversation, "id"),
      clarification_id: setup.dig(:clarification, "id"),
      action: "select",
      option_id: option_id,
      store: setup.fetch(:conversation_store),
      world_store: setup.fetch(:world_store),
      clarification_store: setup.fetch(:clarification_store),
      state_update_proposer: proposer,
      turn_store: setup.fetch(:turn_store),
      proposal_store: setup.fetch(:proposal_store)
    ).call
  end

  def build_active_record_turn
    world_store = WorldState::Stores::ActiveRecord.new
    conversation_store = Conversations::Stores::ActiveRecord.new
    clarification_store = WorldState::ClarificationStores::ActiveRecord.new
    turn_store = Conversations::TurnStores::ActiveRecord.new
    proposal_store = WorldState::ProposalStores::ActiveRecord.new

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

    {
      world_store: world_store,
      conversation_store: conversation_store,
      clarification_store: clarification_store,
      turn_store: turn_store,
      proposal_store: proposal_store,
      world: world,
      conversation: conversation,
      turn: turn,
      clarification: clarification
    }
  end
end
