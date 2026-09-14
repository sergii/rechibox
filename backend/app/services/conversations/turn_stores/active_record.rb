require "securerandom"
require "time"

module Conversations
  module TurnStores
    class ActiveRecord < TurnStore
      CONTRACT_VERSION = "0.1"

      def create(conversation_id:, message_id:)
        now = Time.now.utc.iso8601(6)
        turn = {
          "contract_version" => CONTRACT_VERSION,
          "id" => SecureRandom.uuid,
          "conversation_id" => conversation_id,
          "message_id" => message_id,
          "status" => "processing",
          "created_at" => now,
          "updated_at" => now
        }
        ConversationTurnDocument.create!(
          id: turn.fetch("id"),
          conversation_id: conversation_id,
          payload: turn
        )
        turn
      end

      def fetch(conversation_id:, id:)
        scoped(conversation_id).find(id).payload.deep_dup
      rescue ::ActiveRecord::RecordNotFound
        raise KeyError, "conversation turn not found"
      end

      def list(conversation_id:)
        scoped(conversation_id).order(:created_at, :id).map { |record| record.payload.deep_dup }
      end

      def update(conversation_id:, id:)
        record = scoped(conversation_id).find(id)
        turn = nil
        record.with_lock do
          turn = record.reload.payload.deep_dup
          yield turn
          turn["updated_at"] = Time.now.utc.iso8601(6)
          record.update!(payload: turn)
        end
        turn
      rescue ::ActiveRecord::RecordNotFound
        raise KeyError, "conversation turn not found"
      end

      private

      def scoped(conversation_id)
        ConversationTurnDocument.where(conversation_id: conversation_id)
      end
    end
  end
end
