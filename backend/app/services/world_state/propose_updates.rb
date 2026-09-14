module WorldState
  class ProposeUpdates
    def initialize(world_id:, situation:, proposer: Ai::StateUpdateProposer.default, store: Store.default)
      @world_id = world_id
      @situation = situation.to_h
      @proposer = proposer
      @store = store
    end

    def call
      raise ArgumentError, "situation must not be empty" if @situation.empty?

      world = @store.fetch(@world_id)
      proposals = @proposer.call(situation: @situation, world_state: world)

      {
        "mode" => @proposer.mode,
        "world_id" => world.fetch("id"),
        "proposals" => proposals,
        "usage" => @proposer.usage
      }
    end
  end
end
