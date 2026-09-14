require "test_helper"
require "tmpdir"

class ApiWorldsTest < ActionDispatch::IntegrationTest
  setup do
    @previous_path = ENV["WORLD_STATE_STORE_PATH"]
    @dir = Dir.mktmpdir
    ENV["WORLD_STATE_STORE_PATH"] = @dir
  end

  teardown do
    ENV["WORLD_STATE_STORE_PATH"] = @previous_path
    FileUtils.remove_entry(@dir) if @dir && File.exist?(@dir)
  end

  test "typed state update endpoint persists an explicit relation" do
    post "/api/worlds", as: :json
    assert_response :created
    world_id = response.parsed_body.fetch("id")

    box_id = SecureRandom.uuid
    garage_id = SecureRandom.uuid
    store = WorldState::Store.default
    store.update(id: world_id) do |world|
      world.fetch("entities") << { "id" => box_id, "kind" => "container", "label" => "blue box", "attributes" => {} }
      world.fetch("entities") << { "id" => garage_id, "kind" => "space", "label" => "garage", "attributes" => {} }
    end

    post "/api/worlds/#{world_id}/updates",
         params: {
           update: {
             contract_version: "0.1",
             operation: "assert",
             predicate: "location",
             subject_id: box_id,
             object: { entity_id: garage_id },
             source: "user"
           }
         },
         as: :json

    assert_response :success
    claim = response.parsed_body.fetch("claims").last
    assert_equal "location", claim.fetch("predicate")
    assert_equal garage_id, claim.dig("object", "id")
  end

  test "invalid update is unprocessable" do
    post "/api/worlds", as: :json
    world_id = response.parsed_body.fetch("id")

    post "/api/worlds/#{world_id}/updates", params: { update: { operation: "assert" } }, as: :json

    assert_response :unprocessable_entity
  end
end
