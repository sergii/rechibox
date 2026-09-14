require "securerandom"
require "time"

module WorldState
  module ClarificationStores
    class ActiveRecord < ClarificationStore
      CONTRACT_VERSION = "0.1"

      def create(world_id:, clarification:)
        now = Time.now.utc.iso8601(6)
        record = clarification.merge(
          "contract_version" => CONTRACT_VERSION,
          "id" => SecureRandom.uuid,
          "world_id" => world_id,
          "status" => "pending",
          "created_at" => now,
          "updated_at" => now
        )
        WorldClarificationDocument.create!(id: record.fetch("id"), world_id: world_id, payload: record)
        record
      end

      def fetch(world_id:, id:)
        scoped(world_id).find(id).payload.deep_dup
      rescue ::ActiveRecord::RecordNotFound
        raise KeyError, "clarification not found"
      end

      def list(world_id:)
        scoped(world_id).order(:created_at, :id).map { |row| row.payload.deep_dup }
      end

      def update(world_id:, id:)
        row = scoped(world_id).find(id)
        clarification = nil
        row.with_lock do
          clarification = row.reload.payload.deep_dup
          yield clarification
          clarification["updated_at"] = Time.now.utc.iso8601(6)
          row.update!(payload: clarification)
        end
        clarification
      rescue ::ActiveRecord::RecordNotFound
        raise KeyError, "clarification not found"
      end

      private

      def scoped(world_id)
        WorldClarificationDocument.where(world_id: world_id)
      end
    end
  end
end
