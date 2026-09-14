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
  end
end
