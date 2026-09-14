module WorldState
  class ProposeUpdates
    def initialize(
      world_id:,
      situation:,
      proposer: Ai::StateUpdateProposer.default,
      store: Store.default,
      proposal_store: ProposalStore.default
    )
      @world_id = world_id
      @situation = situation.to_h
      @proposer = proposer
      @store = store
      @proposal_store = proposal_store
    end

    def call
      raise ArgumentError, "situation must not be empty" if @situation.empty?

      world = @store.fetch(@world_id)
      proposed = @proposer.call(situation: @situation, world_state: world)
      proposals = proposed.map do |proposal|
        @proposal_store.create(
          world_id: world.fetch("id"),
          proposal: proposal,
          proposer_mode: @proposer.mode
        )
      end

      {
        "mode" => @proposer.mode,
        "world_id" => world.fetch("id"),
        "proposals" => proposals,
        "usage" => @proposer.usage
      }
    end
  end
end
