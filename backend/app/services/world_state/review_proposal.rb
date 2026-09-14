require "time"

module WorldState
  class ReviewProposal
    ACTIONS = %w[accept reject].freeze

    def initialize(
      world_id:,
      proposal_id:,
      action:,
      rejection_reason: nil,
      proposal_store: ProposalStore.default,
      world_store: Store.default
    )
      @world_id = world_id
      @proposal_id = proposal_id
      @action = action.to_s
      @rejection_reason = rejection_reason.to_s.strip
      @proposal_store = proposal_store
      @world_store = world_store
    end

    def call
      raise ArgumentError, "unsupported proposal review action" unless ACTIONS.include?(@action)

      Persistence.transaction { perform_review }
    end

    private

    def perform_review
      proposal = @proposal_store.fetch(world_id: @world_id, id: @proposal_id)
      raise ArgumentError, "proposal is not pending" unless proposal.fetch("status") == "pending"

      @action == "accept" ? accept(proposal) : reject
    end

    def accept(proposal)
      world = @world_store.fetch(@world_id)
      validation = ValidateUpdate.new(world: world, update: proposal.fetch("update")).call

      unless validation.fetch("valid")
        stale = @proposal_store.update(world_id: @world_id, id: @proposal_id) do |record|
          record["status"] = "stale"
          record["validation"] = validation
          record["resolved_at"] = Time.now.utc.iso8601(6)
        end

        return { "proposal" => stale, "world_state" => world }
      end

      updated_world = ApplyUpdate.new(
        world_id: @world_id,
        update: proposal.fetch("update"),
        store: @world_store
      ).call

      accepted = @proposal_store.update(world_id: @world_id, id: @proposal_id) do |record|
        record["status"] = "accepted"
        record["validation"] = validation
        record["resolved_at"] = Time.now.utc.iso8601(6)
      end

      { "proposal" => accepted, "world_state" => updated_world }
    end

    def reject
      rejected = @proposal_store.update(world_id: @world_id, id: @proposal_id) do |record|
        record["status"] = "rejected"
        record["rejection_reason"] = @rejection_reason unless @rejection_reason.empty?
        record["resolved_at"] = Time.now.utc.iso8601(6)
      end

      { "proposal" => rejected, "world_state" => @world_store.fetch(@world_id) }
    end
  end
end
