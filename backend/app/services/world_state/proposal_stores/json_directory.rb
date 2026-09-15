require "fileutils"
require "json"
require "pathname"
require "securerandom"
require "time"

module WorldState
  module ProposalStores
    class JsonDirectory < ProposalStore
      CONTRACT_VERSION = "0.1"
      UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i

      def initialize(path: ENV.fetch("WORLD_STATE_PROPOSAL_STORE_PATH", "tmp/world-proposals"))
        @path = Pathname.new(path)
      end

      def create(world_id:, proposal:, proposer_mode:, context: nil)
        validate_uuid!(world_id, "world state")
        now = Time.now.utc.iso8601(6)
        lifecycle = normalized_context(context)
        record = {
          "contract_version" => CONTRACT_VERSION,
          "id" => SecureRandom.uuid,
          "world_id" => world_id,
          "status" => "pending",
          "created_at" => now,
          "updated_at" => now,
          "proposer_mode" => proposer_mode,
          "update" => proposal.fetch("update"),
          "reason" => proposal["reason"],
          "validation" => proposal.fetch("validation"),
          "conversation_id" => lifecycle["conversation_id"],
          "message_id" => lifecycle["message_id"],
          "turn_id" => lifecycle["turn_id"]
        }.compact
        write(record)
        record
      end

      def fetch(world_id:, id:)
        validate_uuid!(world_id, "world state")
        validate_uuid!(id, "proposal")
        JSON.parse(File.read(file_path(world_id, id)))
      rescue Errno::ENOENT
        raise KeyError, "proposal not found"
      end

      def list(world_id:)
        validate_uuid!(world_id, "world state")
        directory = world_path(world_id)
        return [] unless directory.directory?

        directory.glob("*.json").sort.map { |path| JSON.parse(File.read(path)) }
      end

      def update(world_id:, id:)
        validate_uuid!(world_id, "world state")
        validate_uuid!(id, "proposal")

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

      def normalized_context(context)
        return {} unless context

        context.to_h.transform_keys(&:to_s).slice("conversation_id", "message_id", "turn_id")
      end
    end
  end
end
