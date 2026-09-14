module Ai
  module WorldQueryInterpreters
    class Disabled < WorldQueryInterpreter
      def mode
        "disabled"
      end

      def call(message:)
        text = message.to_s.strip
        raise ArgumentError, "message must not be blank" if text.empty?

        {
          "contract_version" => "0.1",
          "mode" => mode,
          "query" => nil
        }
      end
    end
  end
end
