require "test_helper"

class WorldStateResolveEntitiesTest < ActiveSupport::TestCase
  setup do
    @box_id = SecureRandom.uuid
    @other_box_id = SecureRandom.uuid
    @world = {
      "id" => SecureRandom.uuid,
      "entities" => [
        {
          "id" => @box_id,
          "kind" => "container",
          "label" => "синя коробка",
          "aliases" => ["box 3"],
          "attributes" => {}
        },
        {
          "id" => @other_box_id,
          "kind" => "container",
          "label" => "червона коробка",
          "aliases" => [],
          "attributes" => {}
        }
      ],
      "claims" => []
    }
  end

  test "resolves an exact alias to a durable entity" do
    result = resolve("E1", "container", "box 3")
    resolution = result.fetch("resolutions").first

    assert_equal "resolved", resolution.fetch("status")
    assert_equal @box_id, resolution.fetch("durable_entity_id")
    assert_equal "exact", resolution.fetch("candidates").first.fetch("match")
  end

  test "resolves a descriptive mention when two meaningful tokens identify one entity" do
    result = resolve("E1", "container", "ця синя коробка")
    resolution = result.fetch("resolutions").first

    assert_equal "resolved", resolution.fetch("status")
    assert_equal @box_id, resolution.fetch("durable_entity_id")
  end

  test "does not resolve a generic one-token mention" do
    result = resolve("E1", "container", "коробка")
    resolution = result.fetch("resolutions").first

    assert_equal "unresolved", resolution.fetch("status")
    assert_nil resolution.fetch("durable_entity_id")
  end

  test "marks equally strong candidates as ambiguous" do
    @world.fetch("entities")[1]["aliases"] = ["storage box"]
    @world.fetch("entities")[0]["aliases"] << "storage box"

    result = resolve("E1", "container", "storage box")
    resolution = result.fetch("resolutions").first

    assert_equal "ambiguous", resolution.fetch("status")
    assert_nil resolution.fetch("durable_entity_id")
  end

  test "kind filters candidates" do
    result = resolve("E1", "space", "синя коробка")
    resolution = result.fetch("resolutions").first

    assert_equal "unresolved", resolution.fetch("status")
    assert_empty resolution.fetch("candidates")
  end

  private

  def resolve(ref, kind, label)
    WorldState::ResolveEntities.new(
      world: @world,
      situation: {
        "entities" => [
          { "ref" => ref, "kind" => kind, "label" => label, "attributes" => {} }
        ]
      }
    ).call
  end
end
