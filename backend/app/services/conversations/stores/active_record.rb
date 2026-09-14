require "securerandom"
require "time"

module Conversations
  module Stores
    class ActiveRecord < Store
      CONTRACT_VERSION = "0.1"

      def create(world_id:)
        now = Time.now.utc.iso8601(6)
        conversation = {
          "contract_version" => CONTRACT_VERSION,
          "id" => SecureRandom.uuid,
          "world_id" => world_id,
          "created_at" => now,
          "updated_at" => now,
          "messages" => []
        }
        ConversationDocument.create!(
          id: conversation.fetch("id"),
          world_id: world_id,
          payload: conversation
        )
        conversation
      end

      def fetch(id)
        ConversationDocument.find(id).payload.deep_dup
      rescue ::ActiveRecord::RecordNotFound
        raise KeyError, "conversation not found"
      end

      def append(id:, messages:)
        record = ConversationDocument.find(id)
        conversation = nil
        record.with_lock do
          conversation = record.reload.payload.deep_dup
          conversation.fetch("messages").concat(Array(messages))
          conversation["updated_at"] = Time.now.utc.iso8601(6)
          record.update!(payload: conversation)
        end
        conversation
      rescue ::ActiveRecord::RecordNotFound
        raise KeyError, "conversation not found"
      end
    end
  end
end
