require "fileutils"
require "json"
require "pathname"
require "securerandom"
require "time"

module WorldState
  module Stores
    class JsonDirectory < Store
      CONTRACT_VERSION = "0.1"

      def initialize(path: ENV.fetch("WORLD_STATE_STORE_PATH", "tmp/worlds"))
        @path = Pathname.new(path)
      end

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
        write(world)
        world
      end

      def fetch(id)
        validate_id!(id)
        JSON.parse(File.read(file_path(id)))
      rescue Errno::ENOENT
        raise KeyError, "world state not found"
      end

      def update(id:)
        validate_id!(id)

        with_lock(id) do
          world = fetch(id)
          yield world
          world["updated_at"] = Time.now.utc.iso8601(6)
          write(world)
          world
        end
      end

      private

      def validate_id!(id)
        value = id.to_s
        raise ArgumentError, "invalid world state id" unless value.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i)
      end

      def file_path(id)
        @path.join("#{id}.json")
      end

      def lock_path(id)
        @path.join("#{id}.lock")
      end

      def with_lock(id)
        FileUtils.mkdir_p(@path)
        File.open(lock_path(id), "w") do |lock|
          lock.flock(File::LOCK_EX)
          yield
        ensure
          lock.flock(File::LOCK_UN)
        end
      end

      def write(world)
        FileUtils.mkdir_p(@path)
        target = file_path(world.fetch("id"))
        temporary = Pathname.new("#{target}.tmp")
        File.write(temporary, JSON.generate(world))
        File.rename(temporary, target)
      end
    end
  end
end
