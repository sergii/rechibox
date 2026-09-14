module Api
  class ConversationsController < ApplicationController
    def create
      render json: Conversations::Store.default.create, status: :created
    end

    def show
      render json: Conversations::Store.default.fetch(params.require(:id))
    rescue KeyError => e
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
