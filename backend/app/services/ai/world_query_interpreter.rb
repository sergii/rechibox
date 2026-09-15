module Ai
  class WorldQueryInterpreter
    def self.default
      case ENV.fetch("AI_WORLD_QUERY_INTERPRETER", "deterministic")
      when "deterministic"
        WorldQueryInterpreters::Deterministic.new
      when "disabled"
        WorldQueryInterpreters::Disabled.new
      when "ruby_llm"
        WorldQueryInterpreters::RubyLlm.new
      else
        raise ArgumentError, "unsupported AI_WORLD_QUERY_INTERPRETER"
      end
    end

    def mode
      raise NotImplementedError, "#{self.class.name} must implement #mode"
    end

    def usage
      ModelUsage.empty
    end

    def call(message:)
      raise NotImplementedError, "#{self.class.name} must implement #call(message:)"
    end
  end
end
