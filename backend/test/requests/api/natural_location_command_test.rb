require "test_helper"

class ApiNaturalLocationCommandTest < ActionDispatch::IntegrationTest
  test "explicit location statement becomes reviewable proposal and accepted world fact" do
    post "/api/worlds", as: :json
    assert_response :created
    world_id = response.parsed_body.fetch("id")
    cables_id = SecureRandom.uuid
    box_id = SecureRandom.uuid

    WorldState::Store.default.update(id: world_id) do |world|
      world.fetch("entities") << { "id" => cables_id, "kind" => "item", "label" => "зарядки", "attributes" => {} }
      world.fetch("entities") << { "id" => box_id, "kind" => "container", "label" => "синя коробка", "attributes" => {} }
    end

    post "/api/worlds/#{world_id}/natural_location_command",
         params: { message: "Я поклав зарядки в синю коробку" },
         as: :json
    assert_response :success

    command = response.parsed_body
    assert_equal "ready_for_review", command.fetch("status")
    proposal = command.fetch("proposal")
    assert_equal "pending", proposal.fetch("status")

    post "/api/worlds/#{world_id}/proposals/#{proposal.fetch("id")}/accept", as: :json
    assert_response :success
    assert_equal "accepted", response.parsed_body.dig("proposal", "status")

    post "/api/worlds/#{world_id}/natural_query",
         params: { message: "Де мої зарядки?" },
         as: :json
    assert_response :success
    assert_equal "resolved", response.parsed_body.dig("answer", "status")
    assert_includes response.parsed_body.dig("answer", "text"), "синя коробка"
  end
end
