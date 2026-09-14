require "test_helper"
require "tmpdir"

class ApiConversationsTest < ActionDispatch::IntegrationTest
  setup do
    @previous_store_path = ENV["CONVERSATION_STORE_PATH"]
    @previous_world_store_path = ENV["WORLD_STATE_STORE_PATH"]
    @store_dir = Dir.mktmpdir
    @world_store_dir = Dir.mktmpdir
    ENV["CONVERSATION_STORE_PATH"] = @store_dir
    ENV["WORLD_STATE_STORE_PATH"] = @world_store_dir
    ENV["ORGANIZED_RUNTIME_PATH"] = Rails.root.join("test/fixtures/organized-v1.jsonl").to_s
  end

  teardown do
    ENV["CONVERSATION_STORE_PATH"] = @previous_store_path
    ENV["WORLD_STATE_STORE_PATH"] = @previous_world_store_path
    FileUtils.remove_entry(@store_dir) if @store_dir && File.exist?(@store_dir)
    FileUtils.remove_entry(@world_store_dir) if @world_store_dir && File.exist?(@world_store_dir)
  end

  test "conversation keeps earlier turns and shares a persistent world state" do
    post "/api/conversations", as: :json

    assert_response :created
    conversation = response.parsed_body
    id = conversation.fetch("id")
    world_id = conversation.fetch("world_id")
    assert_equal "0.1", conversation.fetch("contract_version")
    assert_empty conversation.fetch("messages")

    get "/api/worlds/#{world_id}"
    assert_response :success
    assert_equal world_id, response.parsed_body.fetch("id")

    post "/api/conversations/#{id}/messages",
         params: { message: "У мене маленька кімната і багато коробок.", limit: 2 },
         as: :json

    assert_response :success
    first = response.parsed_body
    assert_equal 1, first.dig("conversation", "messages").size
    assert_empty first.dig("advice", "context", "conversation")
    assert_equal world_id, first.dig("advice", "context", "world_state", "id")

    post "/api/conversations/#{id}/messages",
         params: { message: "А що робити з тими, які я вже продав?", limit: 2 },
         as: :json

    assert_response :success
    second = response.parsed_body
    history = second.dig("advice", "context", "conversation")
    assert_equal 1, history.size
    assert_equal "user", history.first.fetch("role")
    assert_equal "У мене маленька кімната і багато коробок.", history.first.fetch("text")
    assert_equal "А що робити з тими, які я вже продав?", second.dig("advice", "situation", "raw_input")
    assert_equal 2, second.dig("conversation", "messages").size
    assert_equal world_id, second.dig("world_state", "id")

    get "/api/conversations/#{id}"

    assert_response :success
    persisted = response.parsed_body
    assert_equal 2, persisted.fetch("messages").size
    assert_equal world_id, persisted.fetch("world_id")
  end

  test "a new conversation can reuse an existing world" do
    post "/api/worlds", as: :json
    assert_response :created
    world_id = response.parsed_body.fetch("id")

    post "/api/conversations", params: { world_id: world_id }, as: :json
    assert_response :created
    assert_equal world_id, response.parsed_body.fetch("world_id")
  end

  test "unknown conversation returns not found" do
    get "/api/conversations/missing"

    assert_response :not_found
  end
end
