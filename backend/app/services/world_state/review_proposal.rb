require "time"

module WorldState
  class ReviewProposal
    ACTIONS = %w[accept reject].freeze
    TERMINAL_STATUSES = %w[accepted rejected stale].freeze

    def initialize(
      world_id:,
      proposal_id:,
      action:,
      rejection_reason: nil,
      proposal_store: ProposalStore.default,
      world_store: Store.default,
      turn_store: Conversations::TurnStore.default
    )
      @world_id = world_id
      @proposal_id = proposal_id
      @action = action.to_s
      @rejection_reason = rejection_reason.to_s.strip
      @proposal_store = proposal_store
      @world_store = world_store
      @turn_store = turn_store
    end

    def call
      raise ArgumentError, "unsupported proposal review action" unless ACTIONS.include?(@action)

      Persistence.transaction { perform_review }
    end

    private

    def perform_review
      proposal = @proposal_store.fetch(world_id: @world_id, id: @proposal_id)
      raise ArgumentError, "proposal is not pending" unless proposal.fetch("status") == "pending"

      result = @action == "accept" ? accept : reject
      turn = synchronize_turn(result.fetch("proposal"))
      return result unless turn

      result.merge(
        "turn" => turn,
        "conversation_status" => turn.fetch("status")
      )
    end

    def accept
      updated_world = nil
      reviewed = @proposal_store.update(world_id: @world_id, id: @proposal_id) do |record|
        ensure_pending!(record)
        world = @world_store.fetch(@world_id)
        validation = ValidateUpdate.new(world: world, update: record.fetch("update")).call

        if validation.fetch("valid")
          updated_world = ApplyUpdate.new(
            world_id: @world_id,
            update: record.fetch("update"),
            store: @world_store
          ).call
          record["status"] = "accepted"
        else
          updated_world = world
          record["status"] = "stale"
        end

        record["validation"] = validation
        record["resolved_at"] = Time.now.utc.iso8601(6)
      end

      { "proposal" => reviewed, "world_state" => updated_world }
    end

    def reject
      rejected = @proposal_store.update(world_id: @world_id, id: @proposal_id) do |record|
        ensure_pending!(record)
        record["status"] = "rejected"
        record["rejection_reason"] = @rejection_reason unless @rejection_reason.empty?
        record["resolved_at"] = Time.now.utc.iso8601(6)
      end

      { "proposal" => rejected, "world_state" => @world_store.fetch(@world_id) }
    end

    def synchronize_turn(proposal)
      conversation_id = proposal["conversation_id"]
      turn_id = proposal["turn_id"]
      return unless conversation_id && turn_id

      @turn_store.update(conversation_id: conversation_id, id: turn_id) do |turn|
        proposal_ids = Array(turn["proposal_ids"])
        raise ArgumentError, "proposal is not linked to conversation turn" unless proposal_ids.include?(proposal.fetch("id"))

        statuses = proposal_ids.map do |proposal_id|
          @proposal_store.fetch(world_id: @world_id, id: proposal_id).fetch("status")
        end
        target_status = statuses.all? { |status| TERMINAL_STATUSES.include?(status) } ? "completed" : "ready_for_review"

        Conversations::TurnState.transition!(turn, to: target_status)
      end
    end

    def ensure_pending!(record)
      raise ArgumentError, "proposal is not pending" unless record.fetch("status") == "pending"
    end
  end
end
