module Ai
  module SituationExtractors
    class Passthrough < SituationExtractor
      CONTRACT_VERSION = "0.1"

      def mode
        "model_free"
      end

      def call(message:, history: [])
        text = message.to_s.strip
        raise ArgumentError, "message must not be blank" if text.empty?

        {
          "contract_version" => CONTRACT_VERSION,
          "raw_input" => text,
          "facts" => [],
          "goals" => [],
          "constraints" => [],
          "uncertainties" => [],
          "hypotheses" => [],
          "entities" => []
        }
      end
    end
  end
end
