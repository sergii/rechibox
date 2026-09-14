require "fileutils"
require "json"
require "securerandom"
require "time"

module Conversations
  module Stores
    class JsonDirectory < Store
      CONTRACT_VERSION = "0.1"

      def initialize(path: ENV.fetch("CONVERSATION_STORE_PATH", "tmp/conversations"))
        @path = Pathname.new(path)
      end

      def create
        now = Time.now.utc.iso8601(6)
        conversation = {
          "contract_version" => CONTRACT_VERSION,
          "id" => SecureRandom.uuid,
          "created_at" => now,
          "updated_at" => now,
          "messages" => []
        }
        write(conversation)
        conversation
      end

      def fetch(id)
        JSON.parse(File.read(file_path(id)))
      rescue Errno::ENOENT
        raise KeyError, "conversation not found"
      end

      def append(id:, messages:)
        with_lock(id) do
          conversation = fetch(id)
          conversation.fetch("messages").concat(Array(messages))
          conversation["updated_at"] = Time.now.utc.iso8601(6)
          write(conversation)
          conversation
        end
      end

      private

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

      def write(conversation)
        FileUtils.mkdir_p(@path)
        target = file_path(conversation.fetch("id"))
        temporary = Pathname.new("#{target}.tmp")
        File.write(temporary, JSON.generate(conversation))
        File.rename(temporary, target)
      end
    end
  end
end
