module Ai
  module TraceRecorders
    class Disabled < TraceRecorder
      def mode
        "disabled"
      end

      def record(trace:)
        nil
      end
    end
  end
end
