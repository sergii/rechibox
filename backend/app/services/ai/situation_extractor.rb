module Ai
  class SituationExtractor
    def call(message:)
      raise NotImplementedError, "#{self.class.name} must implement #call(message:)"
    end
  end
end
