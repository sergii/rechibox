require "test_helper"

class ApiInventoryWorldQueryVerticalSliceTest < ActionDispatch::IntegrationTest
  setup do
    @previous_interpreter = ENV["AI_WORLD_QUERY_INTERPRETER"]
    ENV["AI_WORLD_QUERY_INTERPRETER"] = "deterministic"
  end

  teardown do
    ENV["AI_WORLD_QUERY_INTERPRETER"] = @previous_interpreter
  end

  test "confirmed inventory becomes queryable without a model call" do
    post "/api/worlds"
    assert_response :created
    world_id = response.parsed_body.fetch("id")

    post "/api/worlds/#{world_id}/inventory_snapshot", params: {
      snapshot: {
        contract_version: "0.1",
        entities: [
          { source_ref: "mobile_inventory:box:1", kind: "container", label: "Синя коробка" },
          {
            source_ref: "mobile_inventory:item:1",
            kind: "item",
            label: "Кабелі",
            location_ref: "mobile_inventory:box:1"
          }
        ]
      }
    }, as: :json
    assert_response :success

    post "/api/worlds/#{world_id}/natural_query", params: { message: "Де мої кабелі?" }, as: :json
    assert_response :success

    body = response.parsed_body
    assert_equal "deterministic", body.fetch("mode")
    assert_equal "resolved", body.dig("answer", "status")
    assert_includes body.dig("answer", "text"), "Синя коробка"
    assert_empty body.dig("usage", "tokens") || {}
  end

  test "inflected Ukrainian box label resolves to imported canonical label" do
    post "/api/worlds"
    world_id = response.parsed_body.fetch("id")

    post "/api/worlds/#{world_id}/inventory_snapshot", params: {
      snapshot: {
        contract_version: "0.1",
        entities: [
          { source_ref: "mobile_inventory:box:1", kind: "container", label: "Синя коробка" },
          {
            source_ref: "mobile_inventory:item:1",
            kind: "item",
            label: "Кабелі",
            location_ref: "mobile_inventory:box:1"
          }
        ]
      }
    }, as: :json

    post "/api/worlds/#{world_id}/natural_query", params: { message: "Що в синій коробці?" }, as: :json
    assert_response :success

    body = response.parsed_body
    assert_equal "resolved", body.dig("resolution", "status")
    assert_equal "resolved", body.dig("answer", "status")
    assert_includes body.dig("answer", "text"), "Кабелі"
  end
end
