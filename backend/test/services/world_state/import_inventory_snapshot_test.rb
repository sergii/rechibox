require "test_helper"

class WorldStateImportInventorySnapshotTest < ActiveSupport::TestCase
  def setup
    @world = {
      "contract_version" => "0.1",
      "id" => "world-1",
      "entities" => [],
      "claims" => []
    }
    @store = WorldState::Stores::Memory.new(@world)
  end

  test "imports boxes and items and creates a physical location claim" do
    result = import(snapshot(
      entity("box:1", "container", "Синя коробка"),
      entity("item:1", "item", "Кабелі", location_ref: "box:1")
    ))

    world = @store.fetch("world-1")
    box_id = result.fetch("entities").fetch("box:1")
    item_id = result.fetch("entities").fetch("item:1")
    claim = world.fetch("claims").sole

    assert_equal 2, result.fetch("created_entities")
    assert_equal "location", claim.fetch("predicate")
    assert_equal item_id, claim.fetch("subject_id")
    assert_equal({ "type" => "entity", "id" => box_id }, claim.fetch("object"))
    assert_equal "imported", claim.fetch("source")
  end

  test "reimport is idempotent and preserves durable entity ids" do
    first = import(snapshot(entity("item:1", "item", "Кабелі", location_ref: nil)))
    second = import(snapshot(entity("item:1", "item", "Кабелі", location_ref: nil)))

    assert_equal first.fetch("entities"), second.fetch("entities")
    assert_equal 0, second.fetch("created_entities")
    assert_equal 1, second.fetch("updated_entities")
    assert_empty @store.fetch("world-1").fetch("claims")
  end

  test "moving an imported item supersedes the previous imported location" do
    first = import(snapshot(
      entity("box:1", "container", "Синя"),
      entity("box:2", "container", "Зелена"),
      entity("item:1", "item", "Кабелі", location_ref: "box:1")
    ))
    old_box_id = first.fetch("entities").fetch("box:1")

    second = import(snapshot(
      entity("box:1", "container", "Синя"),
      entity("box:2", "container", "Зелена"),
      entity("item:1", "item", "Кабелі", location_ref: "box:2")
    ))
    new_box_id = second.fetch("entities").fetch("box:2")
    claims = @store.fetch("world-1").fetch("claims")

    assert_equal 2, claims.length
    assert_equal "superseded", claims.first.fetch("status")
    assert_equal old_box_id, claims.first.dig("object", "id")
    assert_equal "active", claims.last.fetch("status")
    assert_equal new_box_id, claims.last.dig("object", "id")
  end

  test "unassigning an item closes an imported location without inventing a no-location claim" do
    import(snapshot(
      entity("box:1", "container", "Синя"),
      entity("item:1", "item", "Кабелі", location_ref: "box:1")
    ))
    result = import(snapshot(
      entity("box:1", "container", "Синя"),
      entity("item:1", "item", "Кабелі", location_ref: nil)
    ))

    claims = @store.fetch("world-1").fetch("claims")
    assert_equal 1, result.fetch("location_changes")
    assert_equal ["superseded"], claims.map { |claim| claim.fetch("status") }
  end

  test "does not overwrite a stronger explicit location claim" do
    item_id = SecureRandom.uuid
    explicit_box_id = SecureRandom.uuid
    @world.fetch("entities").concat([
      {
        "id" => item_id,
        "kind" => "item",
        "label" => "Кабелі",
        "aliases" => [],
        "attributes" => { "rechibox_source_ref" => "item:1" }
      },
      {
        "id" => explicit_box_id,
        "kind" => "container",
        "label" => "Шафа",
        "aliases" => [],
        "attributes" => {}
      }
    ])
    @world.fetch("claims") << {
      "id" => SecureRandom.uuid,
      "predicate" => "location",
      "subject_id" => item_id,
      "object" => { "type" => "entity", "id" => explicit_box_id },
      "status" => "active",
      "source" => "user"
    }
    @store = WorldState::Stores::Memory.new(@world)

    result = import(snapshot(
      entity("box:1", "container", "Синя"),
      entity("item:1", "item", "Кабелі", location_ref: "box:1")
    ))

    assert_equal ["item:1"], result.fetch("conflicts")
    assert_equal explicit_box_id, @store.fetch("world-1").fetch("claims").sole.dig("object", "id")
  end

  private

  def import(value)
    WorldState::ImportInventorySnapshot.new(
      world_id: "world-1",
      snapshot: value,
      store: @store
    ).call
  end

  def snapshot(*entities)
    { "contract_version" => "0.1", "entities" => entities }
  end

  def entity(source_ref, kind, label, location_ref: :missing)
    value = { "source_ref" => source_ref, "kind" => kind, "label" => label }
    value["location_ref"] = location_ref unless location_ref == :missing
    value
  end
end
