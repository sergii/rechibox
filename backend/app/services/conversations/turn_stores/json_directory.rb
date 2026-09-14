require "fileutils"
require "json"
require "pathname"
require "securerandom"
require "time"

module Conversations
  module TurnStores
    class JsonDirectory < TurnStore
      CONTRACT_VERSION = "0.1"
      UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i

      def initialize(path: ENV.fetch("CONVERSATION_TURN_STORE_PATH", "tmp/conversation-turns"))
        @path = Pathname.new(path)
      end

      def create(conversation_id:, message_id:)
        validate_uuid!(conversation_id, "conversation")
        validate_uuid!(message_id, "message")
        now = Time.now.utc.iso8601(6)
        record = {
          "contract_version" => CONTRACT_VERSION,
          "id" => SecureRandom.uuid,
          "conversation_id" => conversation_id,
          "message_id" => message_id,
          "status" => "processing",
          "created_at" => now,
          "updated_at" => now
        }
        write(record)
        record
      end

      def fetch(conversation_id:, id:)
        validate_uuid!(conversation_id, "conversation")
        validate_uuid!(id, "turn")
        JSON.parse(File.read(file_path(conversation_id, id)))
      rescue Errno::ENOENT
        raise KeyError, "conversation turn not found"
      end

      def list(conversation_id:)
        validate_uuid!(conversation_id, "conversation")
        directory = conversation_path(conversation_id)
        return [] unless directory.directory?

        directory.glob("*.json").sort.map { |path| JSON.parse(File.read(path)) }
      end

      def update(conversation_id:, id:)
        validate_uuid!(conversation_id, "conversation")
        validate_uuid!(id, "turn")

        with_lock(conversation_id, id) do
          record = fetch(conversation_id: conversation_id, id: id)
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

      def conversation_path(conversation_id)
        @path.join(conversation_id)
      end

      def file_path(conversation_id, id)
        conversation_path(conversation_id).join("#{id}.json")
      end

      def lock_path(conversation_id, id)
        conversation_path(conversation_id).join("#{id}.lock")
      end

      def with_lock(conversation_id, id)
        FileUtils.mkdir_p(conversation_path(conversation_id))
        File.open(lock_path(conversation_id, id), "w") do |lock|
          lock.flock(File::LOCK_EX)
          yield
        ensure
          lock.flock(File::LOCK_UN)
        end
      end

      def write(record)
        directory = conversation_path(record.fetch("conversation_id"))
        FileUtils.mkdir_p(directory)
        target = file_path(record.fetch("conversation_id"), record.fetch("id"))
        temporary = Pathname.new("#{target}.tmp")
        File.write(temporary, JSON.generate(record))
        File.rename(temporary, target)
      end
    end
  end
end
