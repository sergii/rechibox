require "securerandom"
require "time"

module WorldState
  module Stores
    class ActiveRecord < Store
      CONTRACT_VERSION = "0.1"

      def create
        now = Time.now.utc.iso8601(6)
        world = {
          "contract_version" => CONTRACT_VERSION,
          "id" => SecureRandom.uuid,
          "created_at" => now,
          "updated_at" => now,
          "entities" => [],
          "claims" => []
        }
        WorldDocument.create!(id: world.fetch("id"), payload: world)
        world
      end

      def fetch(id)
        WorldDocument.find(id).payload.deep_dup
      rescue ::ActiveRecord::RecordNotFound
        raise KeyError, "world state not found"
      end

      def update(id:)
        record = WorldDocument.find(id)
        result = nil
        record.with_lock do
          world = record.reload.payload.deep_dup
          result = yield world
          world["updated_at"] = Time.now.utc.iso8601(6)
          record.update!(payload: world)
          result = world if result.equal?(world)
        end
        result || record.reload.payload.deep_dup
      rescue ::ActiveRecord::RecordNotFound
        raise KeyError, "world state not found"
      end
    end
  end
end
