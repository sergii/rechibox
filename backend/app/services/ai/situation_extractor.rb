module Ai
  class SituationExtractor
    def self.default
      case ENV.fetch("AI_SITUATION_EXTRACTOR", "passthrough")
      when "passthrough"
        SituationExtractors::Passthrough.new
      when "ruby_llm"
        SituationExtractors::RubyLlm.new
      else
        raise ArgumentError, "unsupported AI_SITUATION_EXTRACTOR"
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
