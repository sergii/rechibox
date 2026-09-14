require "test_helper"
require "tmpdir"

class ApiProposalLifecycleTest < ActionDispatch::IntegrationTest
  setup do
    @previous_world_path = ENV["WORLD_STATE_STORE_PATH"]
    @previous_proposal_path = ENV["WORLD_STATE_PROPOSAL_STORE_PATH"]
    @world_dir = Dir.mktmpdir
    @proposal_dir = Dir.mktmpdir
    ENV["WORLD_STATE_STORE_PATH"] = @world_dir
    ENV["WORLD_STATE_PROPOSAL_STORE_PATH"] = @proposal_dir
  end

  teardown do
    ENV["WORLD_STATE_STORE_PATH"] = @previous_world_path
    ENV["WORLD_STATE_PROPOSAL_STORE_PATH"] = @previous_proposal_path
    FileUtils.remove_entry(@world_dir) if File.exist?(@world_dir)
    FileUtils.remove_entry(@proposal_dir) if File.exist?(@proposal_dir)
  end

  test "proposal can be reviewed and accepted through the API" do
    post "/api/worlds", as: :json
    world_id = response.parsed_body.fetch("id")

    box_id = SecureRandom.uuid
    garage_id = SecureRandom.uuid
    world_store = WorldState::Store.default
    world_store.update(id: world_id) do |world|
      world.fetch("entities") << { "id" => box_id, "kind" => "container", "label" => "box", "attributes" => {} }
      world.fetch("entities") << { "id" => garage_id, "kind" => "space", "label" => "garage", "attributes" => {} }
    end

    update = {
      "contract_version" => "0.1",
      "operation" => "assert",
      "predicate" => "location",
      "subject_id" => box_id,
      "object" => { "entity_id" => garage_id }
    }
    proposal = WorldState::ProposalStore.default.create(
      world_id: world_id,
      proposer_mode: "test",
      proposal: {
        "update" => update,
        "reason" => "User moved the box",
        "validation" => WorldState::ValidateUpdate.new(world: world_store.fetch(world_id), update: update).call
      }
    )

    get "/api/worlds/#{world_id}/proposals/#{proposal.fetch("id")}"
    assert_response :success
    assert_equal "pending", response.parsed_body.fetch("status")

    post "/api/worlds/#{world_id}/proposals/#{proposal.fetch("id")}/accept", as: :json
    assert_response :success
    assert_equal "accepted", response.parsed_body.dig("proposal", "status")
    assert_equal "location", response.parsed_body.dig("world_state", "claims", 0, "predicate")

    get "/api/worlds/#{world_id}/proposals"
    assert_response :success
    assert_equal 1, response.parsed_body.fetch("proposals").size
  end
end
