module Api
  class WorldsController < ApplicationController
    def create
      render json: WorldState::Store.default.create, status: :created
    end

    def show
      render json: WorldState::Store.default.fetch(params.require(:id))
    rescue ArgumentError, KeyError => e
      render json: { error: e.message }, status: :not_found
    end

    def update_state
      result = WorldState::ApplyUpdate.new(
        world_id: params.require(:id),
        update: params.require(:update).to_unsafe_h
      ).call

      render json: result
    rescue ActionController::ParameterMissing, ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue KeyError => e
      render json: { error: e.message }, status: :not_found
    end

    def propose_updates
      result = WorldState::ProposeUpdates.new(
        world_id: params.require(:id),
        situation: params.require(:situation).to_unsafe_h
      ).call

      render json: result
    rescue ActionController::ParameterMissing, ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue KeyError => e
      render json: { error: e.message }, status: :not_found
    end

    def proposals
      render json: {
        world_id: params.require(:id),
        proposals: WorldState::ProposalStore.default.list(world_id: params.require(:id))
      }
    rescue ArgumentError, KeyError => e
      render json: { error: e.message }, status: :not_found
    end

    def proposal
      render json: WorldState::ProposalStore.default.fetch(
        world_id: params.require(:id),
        id: params.require(:proposal_id)
      )
    rescue ArgumentError, KeyError => e
      render json: { error: e.message }, status: :not_found
    end

    def accept_proposal
      result = WorldState::ReviewProposal.new(
        world_id: params.require(:id),
        proposal_id: params.require(:proposal_id),
        action: "accept"
      ).call

      status = result.dig("proposal", "status") == "stale" ? :conflict : :ok
      render json: result, status: status
    rescue ActionController::ParameterMissing, ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue KeyError => e
      render json: { error: e.message }, status: :not_found
    end

    def reject_proposal
      result = WorldState::ReviewProposal.new(
        world_id: params.require(:id),
        proposal_id: params.require(:proposal_id),
        action: "reject",
        rejection_reason: params[:reason]
      ).call

      render json: result
    rescue ActionController::ParameterMissing, ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue KeyError => e
      render json: { error: e.message }, status: :not_found
    end
  end
end
