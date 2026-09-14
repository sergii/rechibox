require "test_helper"
require "tmpdir"

class WorldStateProjectSituationTest < ActiveSupport::TestCase
  test "promotes explicit facts and entities but not hypotheses" do
    Dir.mktmpdir do |dir|
      store = WorldState::Stores::JsonDirectory.new(path: dir)
      world = store.create
      situation = {
        "entities" => [
          {
            "ref" => "E1",
            "kind" => "space",
            "label" => "кімната",
            "attributes" => { "area_m2" => 16 }
          }
        ],
        "facts" => [
          { "text" => "Кімната має 16 м².", "source" => "user" }
        ],
        "hypotheses" => [
          { "text" => "Кімната переповнена.", "source" => "inferred", "confidence" => 0.8 }
        ]
      }

      updated = WorldState::ProjectSituation.new(
        world_id: world.fetch("id"),
        situation: situation,
        conversation_id: "conversation-1",
        message_id: "message-1",
        store: store
      ).call

      assert_equal 1, updated.fetch("entities").size
      assert_equal "space", updated.dig("entities", 0, "kind")
      assert_equal 16, updated.dig("entities", 0, "attributes", "area_m2")
      assert_equal 1, updated.fetch("claims").size
      assert_equal "fact", updated.dig("claims", 0, "predicate")
      assert_equal "Кімната має 16 м².", updated.dig("claims", 0, "value")
      assert_equal "message-1", updated.dig("claims", 0, "provenance", "message_id")
      refute updated.fetch("claims").any? { |claim| claim["value"] == "Кімната переповнена." }
    end
  end

  test "uses a resolved durable entity instead of creating a duplicate" do
    Dir.mktmpdir do |dir|
      store = WorldState::Stores::JsonDirectory.new(path: dir)
      world = store.create
      entity_id = SecureRandom.uuid
      store.update(id: world.fetch("id")) do |current|
        current.fetch("entities") << {
          "id" => entity_id,
          "kind" => "container",
          "label" => "синя коробка",
          "aliases" => [],
          "attributes" => {}
        }
      end

      situation = {
        "entities" => [
          {
            "ref" => "E1",
            "kind" => "container",
            "label" => "ця синя коробка",
            "attributes" => { "contents" => "cables" }
          }
        ],
        "facts" => []
      }
      resolution = WorldState::ResolveEntities.new(
        world: store.fetch(world.fetch("id")),
        situation: situation
      ).call

      updated = WorldState::ProjectSituation.new(
        world_id: world.fetch("id"),
        situation: situation,
        conversation_id: "conversation-1",
        message_id: "message-1",
        entity_resolutions: resolution,
        store: store
      ).call

      assert_equal 1, updated.fetch("entities").size
      assert_equal entity_id, updated.dig("entities", 0, "id")
      assert_includes updated.dig("entities", 0, "aliases"), "ця синя коробка"
      assert_equal "cables", updated.dig("entities", 0, "attributes", "contents")
    end
  end

  test "deduplicates repeated explicit facts" do
    Dir.mktmpdir do |dir|
      store = WorldState::Stores::JsonDirectory.new(path: dir)
      world = store.create
      situation = {
        "entities" => [],
        "facts" => [{ "text" => "Коробка належить брату.", "source" => "user" }]
      }

      2.times do |index|
        WorldState::ProjectSituation.new(
          world_id: world.fetch("id"),
          situation: situation,
          conversation_id: "conversation-1",
          message_id: "message-#{index}",
          store: store
        ).call
      end

      assert_equal 1, store.fetch(world.fetch("id")).fetch("claims").size
    end
  end
end
