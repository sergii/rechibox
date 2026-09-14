require "test_helper"

class WorldStateQueryTest < ActiveSupport::TestCase
  setup do
    @store = WorldState::Store.default
    @world = @store.create
    @garage_id = SecureRandom.uuid
    @shelf_id = SecureRandom.uuid
    @box_id = SecureRandom.uuid
    @cables_id = SecureRandom.uuid
    @owner_id = SecureRandom.uuid
    @custodian_id = SecureRandom.uuid

    @store.update(id: @world.fetch("id")) do |world|
      world.fetch("entities").concat([
        entity(@garage_id, "space", "garage"),
        entity(@shelf_id, "furniture", "shelf"),
        entity(@box_id, "container", "blue box"),
        entity(@cables_id, "item", "cables"),
        entity(@owner_id, "person", "owner"),
        entity(@custodian_id, "person", "custodian")
      ])
      world.fetch("claims").concat([
        claim("location", @shelf_id, @garage_id),
        claim("location", @box_id, @shelf_id),
        claim("contains", @box_id, @cables_id),
        claim("ownership", @cables_id, @owner_id),
        claim("custody", @cables_id, @custodian_id)
      ])
    end

    @query = WorldState::Query.new(world_id: @world.fetch("id"))
  end

  test "where_is returns deterministic physical ancestry" do
    result = @query.call(intent: "where_is", entity_id: @cables_id)

    assert_equal false, result.dig("result", "ambiguous")
    assert_equal [@cables_id, @box_id, @shelf_id, @garage_id], result.dig("result", "paths", 0, "entity_ids")
  end

  test "what_is_in returns direct physical children only" do
    result = @query.call(intent: "what_is_in", entity_id: @box_id)

    assert_equal [@cables_id], result.dig("result", "entity_ids")
  end

  test "contents_recursive returns the bounded physical subtree" do
    result = @query.call(intent: "contents_recursive", entity_id: @garage_id, max_depth: 8)

    assert_equal [@garage_id, @shelf_id, @box_id, @cables_id], result.dig("result", "nodes").map { |node| node.fetch("id") }
  end

  test "ownership and custody stay separate query intents" do
    owner = @query.call(intent: "who_owns", entity_id: @cables_id)
    custodian = @query.call(intent: "who_has_custody", entity_id: @cables_id)

    assert_equal [@owner_id], owner.dig("result", "entity_ids")
    assert_equal [@custodian_id], custodian.dig("result", "entity_ids")
  end

  test "multiple owners are surfaced as ambiguity" do
    second_owner = SecureRandom.uuid
    @store.update(id: @world.fetch("id")) do |world|
      world.fetch("entities") << entity(second_owner, "person", "co-owner")
      world.fetch("claims") << claim("ownership", @cables_id, second_owner)
    end

    result = WorldState::Query.new(world_id: @world.fetch("id")).call(intent: "who_owns", entity_id: @cables_id)

    assert_equal true, result.dig("result", "ambiguous")
    assert_equal 2, result.dig("result", "entity_ids").size
  end

  test "unsupported intent is rejected" do
    assert_raises ArgumentError do
      @query.call(intent: "guess_where", entity_id: @cables_id)
    end
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
