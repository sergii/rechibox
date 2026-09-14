require "test_helper"

class ApiWorldGraphTest < ActionDispatch::IntegrationTest
  setup do
    @store = WorldState::Store.default
    @world = @store.create
    @garage_id = SecureRandom.uuid
    @box_id = SecureRandom.uuid

    @store.update(id: @world.fetch("id")) do |world|
      world.fetch("entities") << { "id" => @garage_id, "kind" => "space", "label" => "garage", "aliases" => [], "attributes" => {} }
      world.fetch("entities") << { "id" => @box_id, "kind" => "container", "label" => "box", "aliases" => [], "attributes" => {} }
      world.fetch("claims") << {
        "id" => SecureRandom.uuid,
        "predicate" => "location",
        "subject_id" => @box_id,
        "object" => { "type" => "entity", "id" => @garage_id },
        "status" => "active",
        "source" => "user",
        "confidence" => 1.0
      }
    end
  end

  test "graph endpoint returns a physical subtree" do
    get "/api/worlds/#{@world.fetch("id")}/graph", params: { root_id: @garage_id }

    assert_response :success
    result = response.parsed_body
    assert_equal @garage_id, result.fetch("root_entity_id")
    assert_equal [@garage_id, @box_id], result.fetch("nodes").map { |node| node.fetch("id") }
  end

  test "physical location endpoint returns deterministic ancestry" do
    get "/api/worlds/#{@world.fetch("id")}/entities/#{@box_id}/physical_location"

    assert_response :success
    result = response.parsed_body
    assert_equal false, result.fetch("ambiguous")
    assert_equal [@box_id, @garage_id], result.fetch("paths").first.fetch("entity_ids")
  end

  test "graph endpoint validates max depth" do
    get "/api/worlds/#{@world.fetch("id")}/graph", params: { root_id: @garage_id, max_depth: 0 }

    assert_response :unprocessable_entity
  end
end
