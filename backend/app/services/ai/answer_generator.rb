module Ai
  class AnswerGenerator
    def self.default
      case ENV.fetch("AI_ANSWER_GENERATOR", "disabled")
      when "disabled"
        AnswerGenerators::Disabled.new
      when "ruby_llm"
        AnswerGenerators::RubyLlm.new
      else
        raise ArgumentError, "unsupported AI_ANSWER_GENERATOR"
      end
    end

    def mode
      raise NotImplementedError, "#{self.class.name} must implement #mode"
    end

    def call(context:)
      raise NotImplementedError, "#{self.class.name} must implement #call(context:)"
    end
  end
end
