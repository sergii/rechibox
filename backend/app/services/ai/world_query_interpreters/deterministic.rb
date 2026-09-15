module Ai
  module WorldQueryInterpreters
    class Deterministic < WorldQueryInterpreter
      CONTRACT_VERSION = "0.1"

      PATTERNS = [
        ["contents_recursive", /\A(?:що\s+(?:все\s+)?(?:всередині|міститься\s+в)|what(?:'s|\s+is)\s+(?:everything\s+)?inside)\s+(.+)\z/iu],
        ["what_is_in", /\A(?:що(?:\s+є)?\s+[ув]|what(?:'s|\s+is)\s+in)\s+(.+)\z/iu],
        ["where_is", /\Aде\s+(.+)\z/iu],
        ["where_is", /\Awhere\s+(?:is|are)\s+(.+)\z/iu],
        ["who_owns", /\A(?:кому\s+належить|who\s+owns)\s+(.+)\z/iu],
        ["who_has_custody", /\A(?:хто\s+зберігає|who\s+(?:has|keeps))\s+(.+)\z/iu]
      ].freeze

      LEADING_POSSESSIVES = /\A(?:мої|мій|моя|моє|наші|наш|наша|наше|my|our)\s+/iu

      def mode
        "deterministic"
      end

      def call(message:)
        text = message.to_s.strip
        raise ArgumentError, "message must not be blank" if text.empty?

        intent, label = parse(text)
        return unsupported unless intent && label

        {
          "contract_version" => CONTRACT_VERSION,
          "mode" => mode,
          "query" => {
            "intent" => intent,
            "entity" => {
              "ref" => "E1",
              "kind" => "other",
              "label" => label
            }
          }
        }
      end

      private

      def parse(text)
        normalized = text.strip.sub(/[?!.]+\z/u, "").strip
        PATTERNS.each do |intent, pattern|
          match = pattern.match(normalized)
          next unless match

          label = clean_label(match[1])
          return [intent, label] unless label.empty?
        end
        nil
      end

      def clean_label(value)
        value.to_s.strip.sub(LEADING_POSSESSIVES, "").strip
      end

      def unsupported
        {
          "contract_version" => CONTRACT_VERSION,
          "mode" => mode,
          "query" => nil,
          "reason" => "unsupported"
        }
      end
    end
  end
end
