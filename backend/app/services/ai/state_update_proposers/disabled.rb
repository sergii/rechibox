module Ai
  module StateUpdateProposers
    class Disabled < StateUpdateProposer
      def mode
        "disabled"
      end

      def call(situation:, world_state:)
        []
      end
    end
  end
end
