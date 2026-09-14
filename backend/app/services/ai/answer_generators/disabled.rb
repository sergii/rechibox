module Ai
  module AnswerGenerators
    class Disabled < AnswerGenerator
      def mode
        "disabled"
      end

      def call(context:)
        nil
      end
    end
  end
end
