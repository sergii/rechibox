require "test_helper"
require "tmpdir"

class WorldStateClarificationContractTest < ActiveSupport::TestCase
  test "builds and resolves a clarification without guessing" do
    Dir.mktmpdir do |world_dir|
      Dir.mktmpdir do |clarification_dir|
        world_store = WorldState::Stores::JsonDirectory.new(path: world_dir)
        clarification_store = WorldState::ClarificationStores::JsonDirectory.new(path: clarification_dir)
        world = world_store.create
        blue_id = SecureRandom.uuid
        red_id = SecureRandom.uuid

        world_store.update(id: world.fetch("id")) do |record|
          record.fetch("entities") << { "id" => blue_id, "kind" => "container", "label" => "blue box", "aliases" => [], "attributes" => {} }
          record.fetch("entities") << { "id" => red_id, "kind" => "container", "label" => "red box", "aliases" => [], "attributes" => {} }
        end

        resolution = {
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
          store: clarification_store
        ).call.fetch(0)

        assert_equal "pending", clarification.fetch("status")
        assert_equal 2, clarification.fetch("options").size

        answered = WorldState::AnswerClarification.new(
          world_id: world.fetch("id"),
          clarification_id: clarification.fetch("id"),
          action: "select",
          option_id: "1",
          store: clarification_store,
          world_store: world_store
        ).call

        assert_equal "resolved", answered.fetch("status")
        assert_equal blue_id, answered.fetch("selected_entity_id")
      end
    end
  end

  test "none of the above closes clarification without choosing an entity" do
    Dir.mktmpdir do |world_dir|
      Dir.mktmpdir do |clarification_dir|
        world_store = WorldState::Stores::JsonDirectory.new(path: world_dir)
        clarification_store = WorldState::ClarificationStores::JsonDirectory.new(path: clarification_dir)
        world = world_store.create
        clarification = clarification_store.create(
          world_id: world.fetch("id"),
          clarification: {
            "situation_entity_ref" => "E1",
            "mention" => { "kind" => "container", "label" => "box" },
            "question" => "Which box?",
            "options" => []
          }
        )

        answered = WorldState::AnswerClarification.new(
          world_id: world.fetch("id"),
          clarification_id: clarification.fetch("id"),
          action: "none_of_above",
          store: clarification_store,
          world_store: world_store
        ).call

        assert_equal "none_of_above", answered.fetch("status")
        refute answered.key?("selected_entity_id")
      end
    end
  end
end
