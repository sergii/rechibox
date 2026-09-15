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

  test "resolves an interpreted entity, executes the deterministic query, and renders an answer" do
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
    assert_equal "resolved", result.dig("answer", "status")
    assert_equal "Location of “cables”: blue box → garage.", result.dig("answer", "text")
    assert_equal 2, result.dig("answer", "supporting_claim_ids").size
    assert_nil result["clarification"]
  end

  test "persists ambiguity and resumes the same query after an explicit selection" do
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
    assert_equal "ambiguous", result.dig("answer", "status")
    clarification = result.fetch("clarification")
    assert_equal "pending", clarification.fetch("status")
    assert_equal 2, clarification.fetch("options").size
    assert_equal "natural_query", clarification.dig("resume_context", "kind")

    selected = clarification.fetch("options").find { |option| option.fetch("entity_id") == @box_id }
    resumed = WorldState::ResumeNaturalQuery.new(
      world_id: @world.fetch("id"),
      clarification_id: clarification.fetch("id"),
      action: "select",
      option_id: selected.fetch("option_id"),
      world_store: @store
    ).call

    assert_equal "resolved", resumed.dig("clarification", "status")
    assert_equal @box_id, resumed.dig("resolution", "durable_entity_id")
    assert_equal "what_is_in", resumed.dig("query_result", "intent")
    assert_equal [@cables_id], resumed.dig("query_result", "result", "entity_ids")
    assert_equal "resolved", resumed.dig("answer", "status")
    assert_includes resumed.dig("answer", "text"), "cables"
  end

  test "none of the clarification options closes the query without guessing" do
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

    initial = WorldState::NaturalQuery.new(
      world_id: @world.fetch("id"),
      interpreter: interpreter,
      store: @store
    ).call(message: "What is in the blue box?")

    resumed = WorldState::ResumeNaturalQuery.new(
      world_id: @world.fetch("id"),
      clarification_id: initial.dig("clarification", "id"),
      action: "none_of_above",
      world_store: @store
    ).call

    assert_equal "none_of_above", resumed.dig("clarification", "status")
    assert_nil resumed["query_result"]
    assert_equal "unknown", resumed.dig("answer", "status")
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
    assert_nil result["clarification"]
    assert_nil result["query_result"]
    assert_nil result["answer"]
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
