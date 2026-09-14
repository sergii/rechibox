require "test_helper"
require "tmpdir"

class ApiClarificationsTest < ActionDispatch::IntegrationTest
  setup do
    @previous_world_path = ENV["WORLD_STATE_STORE_PATH"]
    @previous_clarification_path = ENV["WORLD_STATE_CLARIFICATION_STORE_PATH"]
    @world_dir = Dir.mktmpdir
    @clarification_dir = Dir.mktmpdir
    ENV["WORLD_STATE_STORE_PATH"] = @world_dir
    ENV["WORLD_STATE_CLARIFICATION_STORE_PATH"] = @clarification_dir
  end

  teardown do
    ENV["WORLD_STATE_STORE_PATH"] = @previous_world_path
    ENV["WORLD_STATE_CLARIFICATION_STORE_PATH"] = @previous_clarification_path
    FileUtils.remove_entry(@world_dir) if @world_dir && File.exist?(@world_dir)
    FileUtils.remove_entry(@clarification_dir) if @clarification_dir && File.exist?(@clarification_dir)
  end

  test "lists and answers a persisted clarification" do
    post "/api/worlds", as: :json
    world = response.parsed_body
    first_id = SecureRandom.uuid
    second_id = SecureRandom.uuid

    WorldState::Store.default.update(id: world.fetch("id")) do |record|
      record.fetch("entities") << { "id" => first_id, "kind" => "container", "label" => "blue box", "aliases" => [], "attributes" => {} }
      record.fetch("entities") << { "id" => second_id, "kind" => "container", "label" => "red box", "aliases" => [], "attributes" => {} }
    end

    clarification = WorldState::ClarificationStore.default.create(
      world_id: world.fetch("id"),
      clarification: {
        "situation_entity_ref" => "E1",
        "mention" => { "kind" => "container", "label" => "box" },
        "question" => "Which box?",
        "options" => [
          { "option_id" => "1", "entity_id" => first_id, "label" => "blue box", "kind" => "container", "score" => 0.5 },
          { "option_id" => "2", "entity_id" => second_id, "label" => "red box", "kind" => "container", "score" => 0.5 }
        ]
      }
    )

    get "/api/worlds/#{world.fetch("id")}/clarifications"
    assert_response :success
    assert_equal clarification.fetch("id"), response.parsed_body.fetch("clarifications").first.fetch("id")

    post "/api/worlds/#{world.fetch("id")}/clarifications/#{clarification.fetch("id")}/answer",
         params: { action: "select", option_id: "2" }, as: :json

    assert_response :success
    assert_equal "resolved", response.parsed_body.fetch("status")
    assert_equal second_id, response.parsed_body.fetch("selected_entity_id")
  end
end
