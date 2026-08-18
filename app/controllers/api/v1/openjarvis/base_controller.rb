class Api::V1::Openjarvis::BaseController < ApplicationController
  skip_before_action :set_current_user
  before_action :authenticate_openjarvis!

  rescue_from Openjarvis::ApiError, with: :render_openjarvis_error
  rescue_from ActiveRecord::RecordInvalid, with: :render_openjarvis_record_invalid
  rescue_from ActionController::ParameterMissing, with: :render_openjarvis_parameter_missing

  private

  attr_reader :openjarvis_hook, :openjarvis_access_scope

  def authenticate_openjarvis!
    token = bearer_token
    @openjarvis_hook = Integrations::Hook.enabled.find_by(app_id: Openjarvis::Configuration::APP_ID, access_token: token) if token.present?
    raise Openjarvis::ApiError.new('invalid_credentials', 'Invalid or revoked integration credentials', status: :unauthorized) unless openjarvis_hook

    configuration = openjarvis_hook.openjarvis_configuration
    unless configuration.valid?
      raise Openjarvis::ApiError.new('integration_unavailable', 'The integration configuration is incomplete', status: :service_unavailable)
    end

    Current.account = openjarvis_hook.account
    Current.user = configuration.service_user
    Current.account_user = configuration.account_user
    Current.executed_by = configuration.service_user
    @openjarvis_access_scope = Openjarvis::AccessScope.new(openjarvis_hook)
  end

  def bearer_token
    request.authorization.to_s.match(/\ABearer\s+([^\s]+)\z/i)&.captures&.first
  end

  def require_scope!(scope)
    return if openjarvis_hook.openjarvis_configuration.scopes.include?(scope)

    raise Openjarvis::ApiError.new('insufficient_scope', "Required scope: #{scope}", status: :forbidden)
  end

  def page
    [params.fetch(:page, 1).to_i, 1].max
  end

  def limit
    params.fetch(:limit, 25).to_i.clamp(1, 100)
  end

  def paginate(scope)
    scope.offset((page - 1) * limit).limit(limit)
  end

  def pagination_meta(records)
    { page: page, limit: limit, returned: records.size }
  end

  def execute_idempotently(operation, payload, &)
    result = Openjarvis::Idempotency::Executor.new(
      hook: openjarvis_hook,
      key: request.headers['Idempotency-Key'],
      operation: operation,
      payload: payload
    ).execute(&)
    response.set_header('Idempotency-Replayed', result.replayed.to_s)
    render json: result.body, status: result.status
  end

  def idempotent_result(status:, body:, resource: nil)
    Openjarvis::Idempotency::Executor::Result.new(
      status: Rack::Utils.status_code(status),
      body: body,
      resource: resource,
      replayed: false
    )
  end

  def validate_enum_value!(model, attribute, value)
    return if value.blank?

    allowed_values = model.public_send(attribute.to_s.pluralize)
    return if allowed_values.key?(value.to_s)

    raise Openjarvis::ApiError.new(
      "invalid_#{attribute}",
      "#{attribute} must be one of: #{allowed_values.keys.join(', ')}",
      status: :bad_request
    )
  end

  def parse_iso8601!(value, parameter:)
    Time.iso8601(value.to_s)
  rescue ArgumentError
    raise Openjarvis::ApiError.new(
      "invalid_#{parameter}",
      "#{parameter} must be an ISO-8601 timestamp",
      status: :bad_request
    )
  end

  def render_openjarvis_error(error)
    render json: error.response_body, status: error.status
  end

  def render_openjarvis_record_invalid(error)
    render_openjarvis_error(
      Openjarvis::ApiError.new('validation_failed', 'The resource could not be saved', details: error.record.errors.to_hash)
    )
  end

  def render_openjarvis_parameter_missing(error)
    render_openjarvis_error(Openjarvis::ApiError.new('missing_parameter', error.message, status: :bad_request))
  end
end
