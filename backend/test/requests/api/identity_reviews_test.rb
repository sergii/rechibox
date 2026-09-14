require "test_helper"
require "tmpdir"

class ApiIdentityReviewsTest < ActionDispatch::IntegrationTest
  setup do
    @previous_path = ENV["WORLD_STATE_STORE_PATH"]
    @dir = Dir.mktmpdir
    ENV["WORLD_STATE_STORE_PATH"] = @dir
  end

  teardown do
    ENV["WORLD_STATE_STORE_PATH"] = @previous_path
    FileUtils.remove_entry(@dir) if @dir && File.exist?(@dir)
  end

  test "same-entity review merges durable entities" do
    post "/api/worlds", as: :json
    world_id = response.parsed_body.fetch("id")
    canonical_id = SecureRandom.uuid
    alias_id = SecureRandom.uuid

    WorldState::Store.default.update(id: world_id) do |world|
      world.fetch("entities") << { "id" => canonical_id, "kind" => "container", "label" => "blue box", "aliases" => [], "attributes" => {} }
      world.fetch("entities") << { "id" => alias_id, "kind" => "container", "label" => "box 3", "aliases" => [], "attributes" => {} }
    end

    post "/api/worlds/#{world_id}/identity_reviews",
         params: {
           decision: "same_entity",
           canonical_entity_id: canonical_id,
           alias_entity_id: alias_id,
           reason: "same physical box"
         },
         as: :json

    assert_response :success
    merged = response.parsed_body.fetch("entities").find { |entity| entity.fetch("id") == alias_id }
    assert_equal "merged", merged.fetch("status")
    assert_equal canonical_id, merged.fetch("merged_into_entity_id")

    get "/api/worlds/#{world_id}/identity_reviews"
    assert_response :success
    reviews = response.parsed_body.fetch("identity_reviews")
    assert_equal 1, reviews.size
    assert_equal "same_entity", reviews.first.fetch("decision")
  end

  test "different-entities review preserves both active entities" do
    post "/api/worlds", as: :json
    world_id = response.parsed_body.fetch("id")
    left_id = SecureRandom.uuid
    right_id = SecureRandom.uuid

    WorldState::Store.default.update(id: world_id) do |world|
      world.fetch("entities") << { "id" => left_id, "kind" => "container", "label" => "box 3", "aliases" => [], "attributes" => {} }
      world.fetch("entities") << { "id" => right_id, "kind" => "container", "label" => "cable box", "aliases" => [], "attributes" => {} }
    end

    post "/api/worlds/#{world_id}/identity_reviews",
         params: {
           decision: "different_entities",
           left_entity_id: left_id,
           right_entity_id: right_id
         },
         as: :json

    assert_response :success
    entities = response.parsed_body.fetch("entities")
    assert_nil entities.find { |entity| entity.fetch("id") == left_id }["status"]
    assert_nil entities.find { |entity| entity.fetch("id") == right_id }["status"]
  end
end
