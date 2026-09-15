module WorldState
  class ProposeUpdates
    def initialize(
      world_id:,
      situation:,
      proposer: Ai::StateUpdateProposer.default,
      store: Store.default,
      proposal_store: ProposalStore.default,
      conversation_id: nil,
      message_id: nil,
      turn_id: nil
    )
      @world_id = world_id
      @situation = situation.to_h
      @proposer = proposer
      @store = store
      @proposal_store = proposal_store
      @conversation_id = conversation_id
      @message_id = message_id
      @turn_id = turn_id
    end

    def call
      persist(prepared: prepare)
    end

    # Proposal computation may involve a remote model provider. Keep it free of
    # durable writes so callers can run it outside database transactions/locks.
    def prepare
      raise ArgumentError, "situation must not be empty" if @situation.empty?

      world = @store.fetch(@world_id)
      proposed = @proposer.call(situation: @situation, world_state: world)

      {
        "mode" => @proposer.mode,
        "world_id" => world.fetch("id"),
        "proposed" => proposed,
        "usage" => @proposer.usage
      }
    end

    # Persist only a previously computed proposal plan. This phase is local and
    # deterministic and is safe to place inside a short database transaction.
    def persist(prepared:)
      plan = prepared.to_h
      raise ArgumentError, "proposal plan belongs to another world" unless plan.fetch("world_id") == @world_id
      raise ArgumentError, "proposal plan mode changed" unless plan.fetch("mode") == @proposer.mode

      proposals = Array(plan.fetch("proposed")).map do |proposal|
        @proposal_store.create(
          world_id: @world_id,
          proposal: proposal,
          proposer_mode: plan.fetch("mode"),
          context: proposal_context
        )
      end

      {
        "mode" => plan.fetch("mode"),
        "world_id" => @world_id,
        "proposals" => proposals,
        "usage" => plan.fetch("usage")
      }
    end

    private

    def proposal_context
      {
        "conversation_id" => @conversation_id,
        "message_id" => @message_id,
        "turn_id" => @turn_id
      }.compact
    end
  end
end
