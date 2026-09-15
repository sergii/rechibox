module Api
  class WorldInventorySnapshotsController < ApplicationController
    def create
      result = WorldState::ImportInventorySnapshot.new(
        world_id: params.require(:id),
        snapshot: params.require(:snapshot).to_unsafe_h
      ).call

      render json: result
    rescue ActionController::ParameterMissing, ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue KeyError => e
      render json: { error: e.message }, status: :not_found
    end
  end
end
