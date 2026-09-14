module Api
  class WorldQueriesController < ApplicationController
    def entities
      render json: {
        world_id: params.require(:id),
        entities: WorldState::ReadModel.new(world_id: params.require(:id)).entities(entity_filters)
      }
    rescue ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue KeyError => e
      render json: { error: e.message }, status: :not_found
    end

    def claims
      render json: {
        world_id: params.require(:id),
        claims: WorldState::ReadModel.new(world_id: params.require(:id)).claims(claim_filters)
      }
    rescue ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue KeyError => e
      render json: { error: e.message }, status: :not_found
    end

    private

    def entity_filters
      params.permit(:kind, :status, :label).to_h
    end

    def claim_filters
      params.permit(:predicate, :status, :source, :subject_id, :object_entity_id, :object_value).to_h
    end
  end
end
