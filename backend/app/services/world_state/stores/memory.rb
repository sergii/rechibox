module WorldState
  module Stores
    class Memory < Store
      def initialize(world)
        @world = Marshal.load(Marshal.dump(world))
      end

      def create
        raise NotImplementedError, "Memory store requires an existing world"
      end

      def fetch(id)
        raise KeyError, "world state not found" unless @world.fetch("id") == id

        Marshal.load(Marshal.dump(@world))
      end

      def update(id:)
        raise KeyError, "world state not found" unless @world.fetch("id") == id

        yield @world
        @world
      end
    end
  end
end
