require "test_helper"
require "tmpdir"

class ConversationsTurnStoreTest < ActiveSupport::TestCase
  test "persists and updates turn lifecycle" do
    Dir.mktmpdir do |dir|
      store = Conversations::TurnStores::JsonDirectory.new(path: dir)
      conversation_id = SecureRandom.uuid
      message_id = SecureRandom.uuid

      turn = store.create(conversation_id: conversation_id, message_id: message_id)
      assert_equal "processing", turn.fetch("status")

      updated = store.update(conversation_id: conversation_id, id: turn.fetch("id")) do |record|
        record["status"] = "awaiting_clarification"
        record["clarification_ids"] = [SecureRandom.uuid]
      end

      assert_equal "awaiting_clarification", updated.fetch("status")
      assert_equal 1, store.list(conversation_id).size
      assert_equal turn.fetch("id"), store.fetch(conversation_id: conversation_id, id: turn.fetch("id")).fetch("id")
    end
  end
end
