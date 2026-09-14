require "fileutils"
require "json"
require "pathname"
require "securerandom"
require "time"

module WorldState
  module ClarificationStores
    class JsonDirectory < ClarificationStore
      CONTRACT_VERSION = "0.1"
      UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i

      def initialize(path: ENV.fetch("WORLD_STATE_CLARIFICATION_STORE_PATH", "tmp/world-clarifications"))
        @path = Pathname.new(path)
      end

      def create(world_id:, clarification:)
        validate_uuid!(world_id, "world state")
        now = Time.now.utc.iso8601(6)
        record = clarification.merge(
          "contract_version" => CONTRACT_VERSION,
          "id" => SecureRandom.uuid,
          "world_id" => world_id,
          "status" => "pending",
          "created_at" => now,
          "updated_at" => now
        )
        write(record)
        record
      end

      def fetch(world_id:, id:)
        validate_uuid!(world_id, "world state")
        validate_uuid!(id, "clarification")
        JSON.parse(File.read(file_path(world_id, id)))
      rescue Errno::ENOENT
        raise KeyError, "clarification not found"
      end

      def list(world_id:)
        validate_uuid!(world_id, "world state")
        directory = world_path(world_id)
        return [] unless directory.directory?

        directory.glob("*.json").sort.map { |path| JSON.parse(File.read(path)) }
      end

      def update(world_id:, id:)
        validate_uuid!(world_id, "world state")
        validate_uuid!(id, "clarification")

        with_lock(world_id, id) do
          record = fetch(world_id: world_id, id: id)
          yield record
          record["updated_at"] = Time.now.utc.iso8601(6)
          write(record)
          record
        end
      end

      private

      def validate_uuid!(value, label)
        raise ArgumentError, "invalid #{label} id" unless value.to_s.match?(UUID_PATTERN)
      end

      def world_path(world_id)
        @path.join(world_id)
      end

      def file_path(world_id, id)
        world_path(world_id).join("#{id}.json")
      end

      def lock_path(world_id, id)
        world_path(world_id).join("#{id}.lock")
      end

      def with_lock(world_id, id)
        FileUtils.mkdir_p(world_path(world_id))
        File.open(lock_path(world_id, id), "w") do |lock|
          lock.flock(File::LOCK_EX)
          yield
        ensure
          lock.flock(File::LOCK_UN)
        end
      end

      def write(record)
        directory = world_path(record.fetch("world_id"))
        FileUtils.mkdir_p(directory)
        target = file_path(record.fetch("world_id"), record.fetch("id"))
        temporary = Pathname.new("#{target}.tmp")
        File.write(temporary, JSON.generate(record))
        File.rename(temporary, target)
      end
    end
  end
end
