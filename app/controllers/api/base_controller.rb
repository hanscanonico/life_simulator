# frozen_string_literal: true

module Api
  # JSON-only base for the runner API. Every request carries the runner bearer token; when
  # no token is configured the whole API answers 401 rather than standing open.
  class BaseController < ActionController::API
    before_action :authenticate_runner!

    rescue_from ActiveRecord::RecordNotFound do
      render json: { error: "not_found" }, status: :not_found
    end

    rescue_from ActiveRecord::RecordInvalid do |exception|
      render json: { error: exception.record.errors.full_messages }, status: :unprocessable_content
    end

    rescue_from ActionController::ParameterMissing do |exception|
      render json: { error: "missing parameter: #{exception.param}" }, status: :bad_request
    end

    private

    # Metric samples and run summaries are free-form data — the engine names the metrics,
    # Rails only stores them — so no allow-list can describe their keys. They are read off
    # the parsed body and written into a jsonb column, never mass-assigned as attributes.
    def body_params = request.request_parameters

    def authenticate_runner!
      head :unauthorized unless authentic_token?
    end

    def authentic_token?
      expected = configured_token
      return false if expected.blank? || presented_token.blank?

      ActiveSupport::SecurityUtils.secure_compare(presented_token, expected)
    end

    def presented_token
      @presented_token ||= request.authorization.to_s[/\ABearer\s+(.+)\z/, 1].to_s
    end

    def configured_token
      ENV.fetch("RUNNER_TOKEN", nil).presence || Rails.application.credentials.runner_token
    end
  end
end
