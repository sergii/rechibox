module Ai
  class StateUpdateProposer
    def self.default
      case ENV.fetch("AI_STATE_UPDATE_PROPOSER", "disabled")
      when "disabled"
        StateUpdateProposers::Disabled.new
      when "ruby_llm"
        StateUpdateProposers::RubyLlm.new
      else
        raise ArgumentError, "unsupported AI_STATE_UPDATE_PROPOSER"
      end
    end

    def mode
      raise NotImplementedError, "#{self.class.name} must implement #mode"
    end

    def usage
      ModelUsage.empty
    end

    def call(situation:, world_state:)
      raise NotImplementedError, "#{self.class.name} must implement #call(situation:, world_state:)"
    end
  end
end
