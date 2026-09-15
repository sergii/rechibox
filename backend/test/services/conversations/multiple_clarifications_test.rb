require "test_helper"
require "tmpdir"

class ConversationsMultipleClarificationsTest < ActiveSupport::TestCase
  class CountingProposer < Ai::StateUpdateProposer
    attr_reader :calls

    def initialize
      @calls = []
    end

    def mode
      "test"
    end

    def call(situation:, world_state:)
      @calls << { "situation" => situation, "world_state" => world_state }
      []
    end
  end

  test "keeps turn awaiting clarification until every clarification is resolved" do
    with_multiple_clarification_turn do |setup|
      proposer = CountingProposer.new
      first, second = setup.fetch(:clarifications)

      first_result = resume(
        setup: setup,
        clarification: first,
        option_id: "1",
        proposer: proposer
      )

      assert_equal "awaiting_clarification", first_result.fetch("conversation_status")
      assert_equal [second.fetch("id")], first_result.fetch("pending_clarification_ids")
      assert_empty first_result.fetch("state_update_proposals")
      assert_empty proposer.calls

      second_result = resume(
        setup: setup,
        clarification: second,
        option_id: "2",
        proposer: proposer
      )

      assert_equal "completed", second_result.fetch("conversation_status")
      assert_empty second_result.fetch("pending_clarification_ids")
      assert_equal 1, proposer.calls.size

      resolutions = second_result.dig("entity_resolution", "resolutions")
      assert_equal %w[resolved resolved], resolutions.map { |row| row.fetch("status") }
      assert_equal first.dig("options", 0, "entity_id"), resolutions[0].fetch("durable_entity_id")
      assert_equal second.dig("options", 1, "entity_id"), resolutions[1].fetch("durable_entity_id")

      turn = second_result.fetch("turn")
      assert_equal [first.fetch("id"), second.fetch("id")].sort,
        turn.fetch("resolved_clarification_ids").sort
    end
  end

  test "none of above keeps the barrier until siblings close and prevents proposals" do
    with_multiple_clarification_turn do |setup|
      proposer = CountingProposer.new
      first, second = setup.fetch(:clarifications)

      first_result = Conversations::ResumeClarification.new(
        conversation_id: setup.dig(:conversation, "id"),
        clarification_id: first.fetch("id"),
        action: "none_of_above",
        store: setup.fetch(:conversation_store),
        world_store: setup.fetch(:world_store),
        clarification_store: setup.fetch(:clarification_store),
        state_update_proposer: proposer,
        turn_store: setup.fetch(:turn_store)
      ).call

      assert_equal "awaiting_clarification", first_result.fetch("conversation_status")
      assert_equal [second.fetch("id")], first_result.fetch("pending_clarification_ids")
      assert_empty proposer.calls

      second_result = resume(
        setup: setup,
        clarification: second,
        option_id: "1",
        proposer: proposer
      )

      assert_equal "completed", second_result.fetch("conversation_status")
      assert_empty second_result.fetch("state_update_proposals")
      assert_empty proposer.calls
    end
  end

  private

  def resume(setup:, clarification:, option_id:, proposer:)
    Conversations::ResumeClarification.new(
      conversation_id: setup.dig(:conversation, "id"),
      clarification_id: clarification.fetch("id"),
      action: "select",
      option_id: option_id,
      store: setup.fetch(:conversation_store),
      world_store: setup.fetch(:world_store),
      clarification_store: setup.fetch(:clarification_store),
      state_update_proposer: proposer,
      turn_store: setup.fetch(:turn_store)
    ).call
  end

  def with_multiple_clarification_turn
    Dir.mktmpdir do |dir|
      world_store = WorldState::Stores::JsonDirectory.new(path: File.join(dir, "worlds"))
      conversation_store = Conversations::Stores::JsonDirectory.new(path: File.join(dir, "conversations"))
      clarification_store = WorldState::ClarificationStores::JsonDirectory.new(path: File.join(dir, "clarifications"))
      turn_store = Conversations::TurnStores::JsonDirectory.new(path: File.join(dir, "turns"))

      world = world_store.create
      entities = [
        ["blue box", "container"],
        ["red box", "container"],
        ["garage shelf", "furniture"],
        ["basement shelf", "furniture"]
      ].map do |label, kind|
        { "id" => SecureRandom.uuid, "kind" => kind, "label" => label, "attributes" => {} }
      end
      world_store.update(id: world.fetch("id")) do |record|
        record.fetch("entities").concat(entities)
      end

      conversation = conversation_store.create(world_id: world.fetch("id"))
      message_id = SecureRandom.uuid
      turn = turn_store.create(conversation_id: conversation.fetch("id"), message_id: message_id)
      situation = {
        "contract_version" => "0.1",
        "raw_input" => "Move that box to that shelf.",
        "facts" => [],
        "goals" => [],
        "constraints" => [],
        "uncertainties" => [],
        "hypotheses" => [],
        "entities" => [
          { "ref" => "E1", "kind" => "container", "label" => "box", "attributes" => {} },
          { "ref" => "E2", "kind" => "furniture", "label" => "shelf", "attributes" => {} }
        ]
      }
      resolution = {
        "contract_version" => "0.1",
        "world_id" => world.fetch("id"),
        "resolutions" => [
          ambiguous_resolution("E1", "container", "box", entities[0, 2]),
          ambiguous_resolution("E2", "furniture", "shelf", entities[2, 2])
        ]
      }
      clarifications = WorldState::BuildClarifications.new(
        world_id: world.fetch("id"),
        resolution: resolution,
        conversation_id: conversation.fetch("id"),
        message_id: message_id,
        turn_id: turn.fetch("id"),
        situation: situation,
        store: clarification_store
      ).call

      turn_store.update(conversation_id: conversation.fetch("id"), id: turn.fetch("id")) do |record|
        Conversations::TurnState.transition!(record, to: "awaiting_clarification")
        record["clarification_ids"] = clarifications.map { |row| row.fetch("id") }
      end

      yield(
        world_store: world_store,
        conversation_store: conversation_store,
        clarification_store: clarification_store,
        turn_store: turn_store,
        conversation: conversation,
        clarifications: clarifications
      )
    end
  end

  def ambiguous_resolution(ref, kind, label, entities)
    {
      "situation_entity_ref" => ref,
      "kind" => kind,
      "label" => label,
      "status" => "ambiguous",
      "durable_entity_id" => nil,
      "candidates" => entities.map do |entity|
        {
          "entity_id" => entity.fetch("id"),
          "label" => entity.fetch("label"),
          "kind" => entity.fetch("kind"),
          "score" => 0.5,
          "match" => "token_overlap"
        }
      end
    }
  end
end
