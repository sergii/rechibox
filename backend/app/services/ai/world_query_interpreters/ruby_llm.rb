module Ai
  module WorldQueryInterpreters
    class RubyLlm < WorldQueryInterpreter
      CONTRACT_VERSION = "0.1"
      INTENTS = WorldState::Query::INTENTS

      SCHEMA = {
        name: "RechiboxWorldQueryInterpretationV01",
        schema: {
          type: "object",
          additionalProperties: false,
          required: %w[intent entity],
          properties: {
            intent: { type: "string", enum: INTENTS },
            entity: {
              type: "object",
              additionalProperties: false,
              required: %w[ref kind label],
              properties: {
                ref: { type: "string" },
                kind: {
                  type: "string",
                  enum: %w[space item container furniture person collection other]
                },
                label: { type: "string" }
              }
            }
          }
        }
      }.freeze

      INSTRUCTIONS = <<~TEXT.freeze
        Convert the user message into exactly one bounded Rechibox World Query intent.

        Allowed intents:
        - where_is: ask where an entity is physically located
        - what_is_in: ask for direct physical contents of an entity
        - contents_recursive: ask for recursive physical contents
        - who_owns: ask who owns an entity
        - who_has_custody: ask who currently has custody of an entity

        Extract only the entity explicitly referred to by the user.
        Do not answer the question.
        Do not infer missing world facts.
        Do not invent durable IDs.
        Do not choose among ambiguous real-world entities.
        Preserve the user's wording in the entity label where practical.
        Use kind=other when the type is unclear.
      TEXT

      def initialize(model: ENV["AI_WORLD_QUERY_MODEL"], chat: nil)
        @chat = chat || build_chat(model)
        @usage = ModelUsage.empty
      end

      def mode
        "ruby_llm"
      end

      attr_reader :usage

      def call(message:)
        text = message.to_s.strip
        raise ArgumentError, "message must not be blank" if text.empty?

        response = @chat.with_schema(SCHEMA).ask(
          <<~PROMPT
            #{INSTRUCTIONS}

            <user_message>
            #{text}
            </user_message>
          PROMPT
        )

        @usage = ModelUsage.from_response(
          response,
          input_rate_per_million: ENV["AI_WORLD_QUERY_INPUT_USD_PER_1M_TOKENS"],
          output_rate_per_million: ENV["AI_WORLD_QUERY_OUTPUT_USD_PER_1M_TOKENS"]
        )

        normalize(response.content)
      end

      private

      def build_chat(model)
        model = model.to_s.strip
        raise ArgumentError, "AI_WORLD_QUERY_MODEL must be set when AI_WORLD_QUERY_INTERPRETER=ruby_llm" if model.empty?

        RubyLLM.chat(model: model)
      end

      def normalize(content)
        data = content.to_h.transform_keys(&:to_s)
        entity = data.fetch("entity").to_h.transform_keys(&:to_s)
        intent = data.fetch("intent").to_s
        raise ArgumentError, "unsupported world query intent" unless INTENTS.include?(intent)

        {
          "contract_version" => CONTRACT_VERSION,
          "mode" => mode,
          "query" => {
            "intent" => intent,
            "entity" => {
              "ref" => normalized_ref(entity["ref"]),
              "kind" => entity.fetch("kind", "other").to_s,
              "label" => entity.fetch("label").to_s.strip
            }
          }
        }
      end

      def normalized_ref(value)
        ref = value.to_s.strip
        ref.match?(/\AE[0-9]+\z/) ? ref : "E1"
      end
    end
  end
end
