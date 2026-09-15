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

    def graph
      graph = WorldState::Graph.new(world_id: params.require(:id))
      result = if params[:root_id].present?
        graph.physical_tree(root_id: params[:root_id], max_depth: params[:max_depth])
      else
        {
          "contract_version" => "0.1",
          "world_id" => params.require(:id),
          "edges" => graph.relations(predicates: relation_predicates)
        }
      end

      render json: result
    rescue ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue KeyError => e
      render json: { error: e.message }, status: :not_found
    end

    def physical_location
      render json: WorldState::Graph.new(world_id: params.require(:id)).physical_location(
        entity_id: params.require(:entity_id),
        max_depth: params[:max_depth]
      )
    rescue ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue KeyError => e
      render json: { error: e.message }, status: :not_found
    end

    def query
      render json: WorldState::Query.new(world_id: params.require(:id)).call(
        intent: params.require(:intent),
        entity_id: params.require(:entity_id),
        max_depth: params[:max_depth]
      )
    rescue ActionController::ParameterMissing, ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue KeyError => e
      render json: { error: e.message }, status: :not_found
    end

    def natural_query
      render json: WorldState::NaturalQuery.new(world_id: params.require(:id)).call(
        message: params.require(:message),
        max_depth: params[:max_depth]
      )
    rescue ActionController::ParameterMissing, ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue KeyError => e
      render json: { error: e.message }, status: :not_found
    end

    def answer_natural_query_clarification
      render json: WorldState::ResumeNaturalQuery.new(
        world_id: params.require(:id),
        clarification_id: params.require(:clarification_id),
        action: params.require(:clarification_action),
        option_id: params[:option_id]
      ).call
    rescue ActionController::ParameterMissing, ArgumentError => e
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

    def relation_predicates
      value = params[:predicates]
      return WorldState::Graph::RELATION_PREDICATES if value.blank?

      value.to_s.split(",").map(&:strip)
    end
  end
end
