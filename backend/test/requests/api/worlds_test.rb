require "test_helper"
require "tmpdir"

class ApiWorldsTest < ActionDispatch::IntegrationTest
  setup do
    @previous_path = ENV["WORLD_STATE_STORE_PATH"]
    @previous_proposer = ENV["AI_STATE_UPDATE_PROPOSER"]
    @dir = Dir.mktmpdir
    ENV["WORLD_STATE_STORE_PATH"] = @dir
    ENV["AI_STATE_UPDATE_PROPOSER"] = "disabled"
  end

  teardown do
    ENV["WORLD_STATE_STORE_PATH"] = @previous_path
    ENV["AI_STATE_UPDATE_PROPOSER"] = @previous_proposer
    FileUtils.remove_entry(@dir) if @dir && File.exist?(@dir)
  end

  test "entity resolution maps a situation entity to a durable world entity" do
    post "/api/worlds", as: :json
    world_id = response.parsed_body.fetch("id")
    box_id = SecureRandom.uuid

    WorldState::Store.default.update(id: world_id) do |world|
      world.fetch("entities") << {
        "id" => box_id,
        "kind" => "container",
        "label" => "синя коробка",
        "aliases" => ["box 3"],
        "attributes" => {}
      }
    end

    post "/api/worlds/#{world_id}/resolve_entities",
         params: {
           situation: {
             entities: [
               { ref: "E1", kind: "container", label: "ця синя коробка", attributes: {} }
             ]
           }
         },
         as: :json

    assert_response :success
    resolution = response.parsed_body.fetch("resolutions").first
    assert_equal "resolved", resolution.fetch("status")
    assert_equal box_id, resolution.fetch("durable_entity_id")
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

  test "state update proposals are disabled by default and do not mutate the world" do
    post "/api/worlds", as: :json
    assert_response :created
    world = response.parsed_body

    post "/api/worlds/#{world.fetch("id")}/proposals",
         params: {
           situation: {
             contract_version: "0.1",
             raw_input: "Я переніс коробку на полицю.",
             facts: [{ text: "Я переніс коробку на полицю.", source: "user" }],
             goals: [],
             constraints: [],
             uncertainties: [],
             hypotheses: [],
             entities: []
           }
         },
         as: :json

    assert_response :success
    result = response.parsed_body
    assert_equal "disabled", result.fetch("mode")
    assert_empty result.fetch("proposals")

    get "/api/worlds/#{world.fetch("id")}"
    assert_response :success
    assert_empty response.parsed_body.fetch("claims")
  end

  test "invalid update is unprocessable" do
    post "/api/worlds", as: :json
    world_id = response.parsed_body.fetch("id")

    post "/api/worlds/#{world_id}/updates", params: { update: { operation: "assert" } }, as: :json

    assert_response :unprocessable_entity
  end
end
