require "fileutils"
require "json"

module Ai
  module TraceRecorders
    class Jsonl < TraceRecorder
      def initialize(path: ENV["AI_TRACE_PATH"])
        @path = path.to_s.strip
        raise ArgumentError, "AI_TRACE_PATH must be set when AI_TRACE_STORE=jsonl" if @path.empty?
      end

      def mode
        "jsonl"
      end

      def record(trace:)
        FileUtils.mkdir_p(File.dirname(@path))

        File.open(@path, "a") do |file|
          file.flock(File::LOCK_EX)
          file.puts(JSON.generate(trace))
          file.flush
          file.flock(File::LOCK_UN)
        end

        trace.fetch("id")
      end
    end
  end
end
