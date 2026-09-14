module Ai
  class ModelUsage
    EMPTY = {
      "input_tokens" => nil,
      "output_tokens" => nil,
      "estimated_cost_usd" => nil
    }.freeze

    class << self
      def empty
        EMPTY.dup
      end

      def from_response(response, input_rate_per_million: nil, output_rate_per_million: nil)
        input_tokens = token_value(response, :input_tokens)
        output_tokens = token_value(response, :output_tokens)

        {
          "input_tokens" => input_tokens,
          "output_tokens" => output_tokens,
          "estimated_cost_usd" => estimate_cost(
            input_tokens: input_tokens,
            output_tokens: output_tokens,
            input_rate_per_million: input_rate_per_million,
            output_rate_per_million: output_rate_per_million
          )
        }
      end

      private

      def token_value(response, name)
        direct = read_value(response, name)
        return integer_or_nil(direct) unless direct.nil?

        usage = read_value(response, :usage)
        nested = read_value(usage, name)
        integer_or_nil(nested)
      end

      def read_value(object, name)
        return nil if object.nil?
        return object.public_send(name) if object.respond_to?(name)

        if object.respond_to?(:[])
          object[name] || object[name.to_s]
        end
      rescue KeyError, TypeError
        nil
      end

      def integer_or_nil(value)
        return nil if value.nil?

        Integer(value)
      rescue ArgumentError, TypeError
        nil
      end

      def estimate_cost(input_tokens:, output_tokens:, input_rate_per_million:, output_rate_per_million:)
        input_rate = decimal_or_nil(input_rate_per_million)
        output_rate = decimal_or_nil(output_rate_per_million)
        return nil if input_tokens.nil? || output_tokens.nil? || input_rate.nil? || output_rate.nil?

        (((input_tokens * input_rate) + (output_tokens * output_rate)) / 1_000_000.0).round(8)
      end

      def decimal_or_nil(value)
        text = value.to_s.strip
        return nil if text.empty?

        Float(text)
      rescue ArgumentError, TypeError
        nil
      end
    end
  end
end
