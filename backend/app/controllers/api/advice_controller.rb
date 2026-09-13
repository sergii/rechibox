module Api
  class AdviceController < ApplicationController
    def create
      result = Advice::Generate.new(
        message: params.require(:message),
        limit: optional_limit
      ).call

      render json: result
    rescue ActionController::ParameterMissing, ArgumentError, KeyError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue Errno::ENOENT => e
      render json: { error: e.message }, status: :service_unavailable
    end

    def dry_run
      result = Advice::DryRun.new(
        situation: params.require(:situation).to_unsafe_h,
        limit: optional_limit
      ).call

      render json: result
    rescue ActionController::ParameterMissing, ArgumentError, KeyError => e
      render json: { error: e.message }, status: :unprocessable_entity
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
