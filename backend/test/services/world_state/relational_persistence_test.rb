require "test_helper"

class RelationalWorldStatePersistenceTest < ActiveSupport::TestCase
  setup do
    @store = WorldState::Stores::ActiveRecord.new
    @world = @store.create
  end

  test "entities and claims are stored relationally while the public contract stays unchanged" do
    entity_id = SecureRandom.uuid
    claim_id = SecureRandom.uuid

    updated = @store.update(id: @world.fetch("id")) do |world|
      world.fetch("entities") << {
        "id" => entity_id,
        "kind" => "container",
        "label" => "blue box",
        "aliases" => ["box 3"],
        "attributes" => { "material" => "plastic" }
      }
      world.fetch("claims") << {
        "id" => claim_id,
        "predicate" => "location",
        "subject_id" => entity_id,
        "object" => { "type" => "value", "value" => "garage" },
        "status" => "active",
        "source" => "user"
      }
    end

    assert_equal [entity_id], updated.fetch("entities").map { |entity| entity.fetch("id") }
    assert_equal [claim_id], updated.fetch("claims").map { |claim| claim.fetch("id") }

    document = WorldDocument.find(@world.fetch("id"))
    refute document.payload.key?("entities")
    refute document.payload.key?("claims")

    entity = WorldEntity.find(entity_id)
    assert_equal @world.fetch("id"), entity.world_id
    assert_equal "container", entity.kind
    assert_equal "blue box", entity.label
    assert_equal ["box 3"], entity.payload.fetch("aliases")

    claim = WorldClaim.find(claim_id)
    assert_equal "location", claim.predicate
    assert_equal entity_id, claim.subject_id
    assert_equal "active", claim.status
    assert_equal "user", claim.source
    assert_equal({ "type" => "value", "value" => "garage" }, claim.object)

    assert_equal updated, @store.fetch(@world.fetch("id"))
  end

  test "relational records track updates, removals, and contract order" do
    first_id = SecureRandom.uuid
    second_id = SecureRandom.uuid

    @store.update(id: @world.fetch("id")) do |world|
      world.fetch("entities").concat([
        { "id" => first_id, "kind" => "container", "label" => "first", "attributes" => {} },
        { "id" => second_id, "kind" => "container", "label" => "second", "attributes" => {} }
      ])
    end

    @store.update(id: @world.fetch("id")) do |world|
      second = world.fetch("entities").find { |entity| entity.fetch("id") == second_id }
      second["label"] = "renamed second"
      world["entities"] = [second]
    end

    assert_not WorldEntity.exists?(first_id)
    assert_equal "renamed second", WorldEntity.find(second_id).label
    assert_equal [second_id], @store.fetch(@world.fetch("id")).fetch("entities").map { |entity| entity.fetch("id") }
    assert_equal 0, WorldEntity.find(second_id).position
  end

  test "indexed relational columns support physical-world queries" do
    box_id = SecureRandom.uuid
    shelf_id = SecureRandom.uuid

    @store.update(id: @world.fetch("id")) do |world|
      world.fetch("entities").concat([
        { "id" => box_id, "kind" => "container", "label" => "cables", "attributes" => {} },
        { "id" => shelf_id, "kind" => "furniture", "label" => "garage shelf", "attributes" => {} }
      ])
      world.fetch("claims") << {
        "id" => SecureRandom.uuid,
        "predicate" => "location",
        "subject_id" => box_id,
        "object" => { "type" => "entity", "id" => shelf_id },
        "status" => "active",
        "source" => "user"
      }
    end

    assert_equal [box_id], WorldEntity.where(world_id: @world.fetch("id"), kind: "container").pluck(:id)

    locations = WorldClaim.where(
      world_id: @world.fetch("id"),
      predicate: "location",
      status: "active",
      subject_id: box_id
    )
    assert_equal 1, locations.count
    assert_equal shelf_id, locations.first.object.fetch("id")
  end
end
