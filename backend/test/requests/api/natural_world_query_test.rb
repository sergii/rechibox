require "test_helper"

class ApiNaturalWorldQueryTest < ActionDispatch::IntegrationTest
  setup do
    @previous_interpreter = ENV["AI_WORLD_QUERY_INTERPRETER"]
    ENV["AI_WORLD_QUERY_INTERPRETER"] = "disabled"
  end

  teardown do
    ENV["AI_WORLD_QUERY_INTERPRETER"] = @previous_interpreter
  end

  test "natural query endpoint is fail closed by default" do
    post "/api/worlds", as: :json
    assert_response :created
    world_id = response.parsed_body.fetch("id")

    post "/api/worlds/#{world_id}/natural_query",
         params: { message: "Де мої кабелі?" },
         as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal "disabled", body.fetch("mode")
    assert_nil body["resolution"]
    assert_nil body["query_result"]
    assert_nil body.dig("usage", "input_tokens")
  end

  test "blank message is unprocessable" do
    post "/api/worlds", as: :json
    world_id = response.parsed_body.fetch("id")

    post "/api/worlds/#{world_id}/natural_query",
         params: { message: " " },
         as: :json

    assert_response :unprocessable_entity
  end
end
