require "test_helper"

class WorldStateNaturalQueryTest < ActiveSupport::TestCase
  class FakeInterpreter < Ai::WorldQueryInterpreter
    attr_reader :usage

    def initialize(result)
      @result = result
      @usage = Ai::ModelUsage.empty
    end

    def mode
      "fake"
    end

    def call(message:)
      raise ArgumentError, "message must not be blank" if message.to_s.strip.empty?

      @result
    end
  end

  setup do
    @store = WorldState::Store.default
    @world = @store.create
    @garage_id = SecureRandom.uuid
    @box_id = SecureRandom.uuid
    @cables_id = SecureRandom.uuid

    @store.update(id: @world.fetch("id")) do |world|
      world.fetch("entities").concat([
        entity(@garage_id, "space", "garage"),
        entity(@box_id, "container", "blue box"),
        entity(@cables_id, "item", "cables")
      ])
      world.fetch("claims").concat([
        claim("location", @box_id, @garage_id),
        claim("contains", @box_id, @cables_id)
      ])
    end
  end

  test "resolves an interpreted entity and executes the deterministic query" do
    interpreter = FakeInterpreter.new(
      "contract_version" => "0.1",
      "mode" => "fake",
      "query" => {
        "intent" => "where_is",
        "entity" => { "ref" => "E1", "kind" => "item", "label" => "cables" }
      }
    )

    result = WorldState::NaturalQuery.new(
      world_id: @world.fetch("id"),
      interpreter: interpreter,
      store: @store
    ).call(message: "Where are my cables?")

    assert_equal "resolved", result.dig("resolution", "status")
    assert_equal @cables_id, result.dig("resolution", "durable_entity_id")
    assert_equal "where_is", result.dig("query_result", "intent")
    assert_equal [@cables_id, @box_id, @garage_id], result.dig("query_result", "result", "paths", 0, "entity_ids")
  end

  test "does not execute query when entity resolution is ambiguous" do
    second_box_id = SecureRandom.uuid
    @store.update(id: @world.fetch("id")) do |world|
      world.fetch("entities") << entity(second_box_id, "container", "blue box")
    end

    interpreter = FakeInterpreter.new(
      "contract_version" => "0.1",
      "mode" => "fake",
      "query" => {
        "intent" => "what_is_in",
        "entity" => { "ref" => "E1", "kind" => "container", "label" => "blue box" }
      }
    )

    result = WorldState::NaturalQuery.new(
      world_id: @world.fetch("id"),
      interpreter: interpreter,
      store: @store
    ).call(message: "What is in the blue box?")

    assert_equal "ambiguous", result.dig("resolution", "status")
    assert_nil result["query_result"]
  end

  test "disabled interpreter makes zero-query result without reading world state" do
    missing_world_id = SecureRandom.uuid

    result = WorldState::NaturalQuery.new(
      world_id: missing_world_id,
      interpreter: Ai::WorldQueryInterpreters::Disabled.new,
      store: @store
    ).call(message: "Where are my cables?")

    assert_equal "disabled", result.fetch("mode")
    assert_nil result["resolution"]
    assert_nil result["query_result"]
  end

  private

  def entity(id, kind, label)
    {
      "id" => id,
      "kind" => kind,
      "label" => label,
      "aliases" => [],
      "attributes" => {}
    }
  end

  def claim(predicate, subject_id, object_id)
    {
      "id" => SecureRandom.uuid,
      "predicate" => predicate,
      "subject_id" => subject_id,
      "object" => { "type" => "entity", "id" => object_id },
      "status" => "active",
      "source" => "user",
      "confidence" => 1.0
    }
  end
end
