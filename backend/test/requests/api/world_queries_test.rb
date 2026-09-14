require "test_helper"

class ApiWorldQueriesTest < ActionDispatch::IntegrationTest
  test "queries entities and claims through indexed relational fields" do
    post "/api/worlds", as: :json
    assert_response :created
    world_id = response.parsed_body.fetch("id")

    box_id = SecureRandom.uuid
    shelf_id = SecureRandom.uuid
    store = WorldState::Store.default
    store.update(id: world_id) do |world|
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

    get "/api/worlds/#{world_id}/entities", params: { kind: "container" }
    assert_response :success
    entities = response.parsed_body.fetch("entities")
    assert_equal [box_id], entities.map { |entity| entity.fetch("id") }

    get "/api/worlds/#{world_id}/claims",
        params: { predicate: "location", status: "active", object_entity_id: shelf_id }
    assert_response :success
    claims = response.parsed_body.fetch("claims")
    assert_equal 1, claims.size
    assert_equal box_id, claims.first.fetch("subject_id")
  end

  test "query endpoint returns not found for an unknown world" do
    get "/api/worlds/#{SecureRandom.uuid}/entities", params: { kind: "container" }

    assert_response :not_found
  end
end
