require "test_helper"
require "tmpdir"

class ConversationsResumeClarificationTest < ActiveSupport::TestCase
  test "resumes the suspended turn with the selected durable entity" do
    Dir.mktmpdir do |dir|
      world_store = WorldState::Stores::JsonDirectory.new(path: File.join(dir, "worlds"))
      conversation_store = Conversations::Stores::JsonDirectory.new(path: File.join(dir, "conversations"))
      clarification_store = WorldState::ClarificationStores::JsonDirectory.new(path: File.join(dir, "clarifications"))

      world = world_store.create
      blue_id = SecureRandom.uuid
      red_id = SecureRandom.uuid
      world_store.update(id: world.fetch("id")) do |record|
        record.fetch("entities") << { "id" => blue_id, "kind" => "container", "label" => "blue box", "attributes" => {} }
        record.fetch("entities") << { "id" => red_id, "kind" => "container", "label" => "red box", "attributes" => {} }
      end
      conversation = conversation_store.create(world_id: world.fetch("id"))

      situation = {
        "contract_version" => "0.1",
        "raw_input" => "Move that box to the shelf.",
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
        message_id: SecureRandom.uuid,
        situation: situation,
        store: clarification_store
      ).call.first

      result = Conversations::ResumeClarification.new(
        conversation_id: conversation.fetch("id"),
        clarification_id: clarification.fetch("id"),
        action: "select",
        option_id: "2",
        store: conversation_store,
        world_store: world_store,
        clarification_store: clarification_store,
        state_update_proposer: Ai::StateUpdateProposers::Disabled.new
      ).call

      assert_equal "resumed", result.fetch("conversation_status")
      row = result.dig("entity_resolution", "resolutions", 0)
      assert_equal "resolved", row.fetch("status")
      assert_equal red_id, row.fetch("durable_entity_id")
      assert_equal clarification.fetch("id"), row.dig("resolved_by", "clarification_id")
      assert_empty result.fetch("state_update_proposals")
    end
  end

  test "none of above closes the clarification without resuming proposals" do
    Dir.mktmpdir do |dir|
      world_store = WorldState::Stores::JsonDirectory.new(path: File.join(dir, "worlds"))
      conversation_store = Conversations::Stores::JsonDirectory.new(path: File.join(dir, "conversations"))
      clarification_store = WorldState::ClarificationStores::JsonDirectory.new(path: File.join(dir, "clarifications"))

      world = world_store.create
      conversation = conversation_store.create(world_id: world.fetch("id"))
      clarification = clarification_store.create(
        world_id: world.fetch("id"),
        clarification: {
          "situation_entity_ref" => "E1",
          "mention" => { "kind" => "container", "label" => "box" },
          "question" => "Which box?",
          "options" => [
            { "option_id" => "1", "entity_id" => SecureRandom.uuid, "label" => "blue box", "kind" => "container", "score" => 0.5 }
          ],
          "resume_context" => {
            "conversation_id" => conversation.fetch("id"),
            "message_id" => SecureRandom.uuid,
            "situation" => { "raw_input" => "box" },
            "entity_resolution" => { "resolutions" => [] }
          }
        }
      )

      result = Conversations::ResumeClarification.new(
        conversation_id: conversation.fetch("id"),
        clarification_id: clarification.fetch("id"),
        action: "none_of_above",
        store: conversation_store,
        world_store: world_store,
        clarification_store: clarification_store,
        state_update_proposer: Ai::StateUpdateProposers::Disabled.new
      ).call

      assert_equal "clarification_unresolved", result.fetch("conversation_status")
      assert_equal "none_of_above", result.dig("clarification", "status")
      assert_empty result.fetch("state_update_proposals")
    end
  end
end
