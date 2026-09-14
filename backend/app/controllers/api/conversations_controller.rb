module Api
  class ConversationsController < ApplicationController
    def create
      world_store = WorldState::Store.default
      world = if params[:world_id].present?
        world_store.fetch(params[:world_id])
      else
        world_store.create
      end

      conversation = Conversations::Store.default.create(world_id: world.fetch("id"))
      render json: conversation, status: :created
    rescue ArgumentError, KeyError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def show
      render json: Conversations::Store.default.fetch(params.require(:id))
    rescue KeyError => e
      render json: { error: e.message }, status: :not_found
    end

    def turns
      render json: {
        conversation_id: params.require(:id),
        turns: Conversations::TurnStore.default.list(params.require(:id))
      }
    rescue ArgumentError, KeyError => e
      render json: { error: e.message }, status: :not_found
    end

    def turn
      render json: Conversations::TurnStore.default.fetch(
        conversation_id: params.require(:id),
        id: params.require(:turn_id)
      )
    rescue ArgumentError, KeyError => e
      render json: { error: e.message }, status: :not_found
    end

    def reply
      result = Conversations::Reply.new(
        conversation_id: params.require(:id),
        message: params.require(:message),
        limit: optional_limit
      ).call

      render json: result
    rescue ActionController::ParameterMissing, ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue KeyError => e
      render json: { error: e.message }, status: :not_found
    rescue Errno::ENOENT => e
      render json: { error: e.message }, status: :service_unavailable
    end

    def resume_clarification
      result = Conversations::ResumeClarification.new(
        conversation_id: params.require(:id),
        clarification_id: params.require(:clarification_id),
        action: params.require(:action),
        option_id: params[:option_id]
      ).call

      render json: result
    rescue ActionController::ParameterMissing, ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue KeyError => e
      render json: { error: e.message }, status: :not_found
    end

    private

    def optional_limit
      value = params[:limit]
      return nil if value.blank?

      Integer(value, 10).tap do |limit|
        raise ArgumentError, "limit must be >= 1" if limit < 1
      end
    end
  end
end
