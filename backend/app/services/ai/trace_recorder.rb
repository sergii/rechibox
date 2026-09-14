module Ai
  class TraceRecorder
    def self.default
      case ENV.fetch("AI_TRACE_STORE", "disabled")
      when "disabled"
        TraceRecorders::Disabled.new
      when "jsonl"
        TraceRecorders::Jsonl.new
      else
        raise ArgumentError, "unsupported AI_TRACE_STORE"
      end
    end

    def mode
      raise NotImplementedError, "#{self.class.name} must implement #mode"
    end

    def record(trace:)
      raise NotImplementedError, "#{self.class.name} must implement #record(trace:)"
    end
  end
end
