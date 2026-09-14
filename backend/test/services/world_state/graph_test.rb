require "test_helper"

class WorldStateGraphTest < ActiveSupport::TestCase
  setup do
    @store = WorldState::Store.default
    @world = @store.create
    @garage_id = SecureRandom.uuid
    @shelf_id = SecureRandom.uuid
    @box_id = SecureRandom.uuid
    @cables_id = SecureRandom.uuid
    @owner_id = SecureRandom.uuid

    @store.update(id: @world.fetch("id")) do |world|
      world.fetch("entities").concat([
        entity(@garage_id, "space", "garage"),
        entity(@shelf_id, "furniture", "shelf"),
        entity(@box_id, "container", "blue box"),
        entity(@cables_id, "item", "cables"),
        entity(@owner_id, "person", "Serhii")
      ])
      world.fetch("claims").concat([
        claim("location", @shelf_id, @garage_id),
        claim("location", @box_id, @shelf_id),
        claim("contains", @box_id, @cables_id),
        claim("ownership", @cables_id, @owner_id)
      ])
    end

    @graph = WorldState::Graph.new(world_id: @world.fetch("id"))
  end

  test "physical tree normalizes location and contains into parent to child edges" do
    result = @graph.physical_tree(root_id: @garage_id)

    assert_equal [@garage_id, @shelf_id, @box_id, @cables_id], result.fetch("nodes").map { |node| node.fetch("id") }
    assert_equal [
      [@garage_id, @shelf_id, "location"],
      [@shelf_id, @box_id, "location"],
      [@box_id, @cables_id, "contains"]
    ], result.fetch("edges").map { |edge| [edge.fetch("from_entity_id"), edge.fetch("to_entity_id"), edge.fetch("predicate")] }
  end

  test "physical location walks from an item through nested containers to the outer space" do
    result = @graph.physical_location(entity_id: @cables_id)
    path = result.fetch("paths").first

    assert_equal false, result.fetch("ambiguous")
    assert_equal [@cables_id, @box_id, @shelf_id, @garage_id], path.fetch("entity_ids")
    assert_equal false, path.fetch("cycle")
    assert_equal false, path.fetch("truncated")
  end

  test "physical location reports ambiguity instead of choosing a parent" do
    second_shelf = SecureRandom.uuid
    @store.update(id: @world.fetch("id")) do |world|
      world.fetch("entities") << entity(second_shelf, "furniture", "other shelf")
      world.fetch("claims") << claim("location", @box_id, second_shelf)
    end

    result = WorldState::Graph.new(world_id: @world.fetch("id")).physical_location(entity_id: @cables_id)

    assert_equal true, result.fetch("ambiguous")
    assert_equal 2, result.fetch("paths").size
  end

  test "relations exposes raw typed relation direction without inferring physical direction" do
    edges = @graph.relations(predicates: ["ownership"])

    assert_equal 1, edges.size
    assert_equal @cables_id, edges.first.fetch("from_entity_id")
    assert_equal @owner_id, edges.first.fetch("to_entity_id")
    assert_equal "ownership", edges.first.fetch("predicate")
  end

  test "physical traversal is cycle safe" do
    @store.update(id: @world.fetch("id")) do |world|
      world.fetch("claims") << claim("contains", @cables_id, @garage_id)
    end

    result = WorldState::Graph.new(world_id: @world.fetch("id")).physical_tree(root_id: @garage_id)

    assert result.fetch("cycles").any?
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
