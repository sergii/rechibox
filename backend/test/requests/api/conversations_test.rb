require "test_helper"
require "tmpdir"

class ApiConversationsTest < ActionDispatch::IntegrationTest
  setup do
    @previous_store_path = ENV["CONVERSATION_STORE_PATH"]
    @store_dir = Dir.mktmpdir
    ENV["CONVERSATION_STORE_PATH"] = @store_dir
    ENV["ORGANIZED_RUNTIME_PATH"] = Rails.root.join("test/fixtures/organized-v1.jsonl").to_s
  end

  teardown do
    ENV["CONVERSATION_STORE_PATH"] = @previous_store_path
    FileUtils.remove_entry(@store_dir) if @store_dir && File.exist?(@store_dir)
  end

  test "conversation keeps earlier turns and feeds them into the next advice request" do
    post "/api/conversations", as: :json

    assert_response :created
    conversation = response.parsed_body
    id = conversation.fetch("id")
    assert_equal "0.1", conversation.fetch("contract_version")
    assert_empty conversation.fetch("messages")

    post "/api/conversations/#{id}/messages",
         params: { message: "У мене маленька кімната і багато коробок.", limit: 2 },
         as: :json

    assert_response :success
    first = response.parsed_body
    assert_equal 1, first.dig("conversation", "messages").size
    assert_empty first.dig("advice", "context", "conversation")

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

    get "/api/conversations/#{id}"

    assert_response :success
    persisted = response.parsed_body
    assert_equal 2, persisted.fetch("messages").size
  end

  test "unknown conversation returns not found" do
    get "/api/conversations/missing"

    assert_response :not_found
  end
end
