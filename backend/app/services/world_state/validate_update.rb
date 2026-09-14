module WorldState
  class ValidateUpdate
    def initialize(world:, update:)
      @world = world
      @update = update
    end

    def call
      store = Stores::Memory.new(@world)
      ApplyUpdate.new(
        world_id: @world.fetch("id"),
        update: @update,
        store: store
      ).call

      { "valid" => true, "error" => nil }
    rescue ArgumentError, KeyError => e
      { "valid" => false, "error" => e.message }
    end
  end
end
