class Api::V1::Openjarvis::BaseController < ApplicationController
  skip_before_action :set_current_user
  before_action :authenticate_openjarvis!
  before_action :enforce_openjarvis_rate_limit!

  rescue_from StandardError, with: :render_openjarvis_internal_error
  rescue_from Openjarvis::ApiError, with: :render_openjarvis_error
  rescue_from ActiveRecord::RecordInvalid, with: :render_openjarvis_record_invalid
  rescue_from ActionController::ParameterMissing, with: :render_openjarvis_parameter_missing
  rescue_from ActiveRecord::RecordNotFound, with: :render_openjarvis_not_found

  private

  attr_reader :openjarvis_hook, :openjarvis_access_scope

  def authenticate_openjarvis!
    token = bearer_token
    @openjarvis_hook = find_hook_by_token(token) if token.present?
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

  def find_hook_by_token(token)
    scope = Integrations::Hook.enabled.where(app_id: Openjarvis::Configuration::APP_ID)
    hook = scope.find_by(access_token: token) || scope.find_by(previous_access_token: token)
    hook if hook&.accepts_openjarvis_access_token?(token)
  end

  def require_scope!(scope)
    return if openjarvis_hook.openjarvis_configuration.scopes.include?(scope)

    raise Openjarvis::ApiError.new('insufficient_scope', "Required scope: #{scope}", status: :forbidden)
  end

  def limit
    params.fetch(:limit, 25).to_i.clamp(1, 100)
  end

  def cursor_page(scope, type:, timestamp_column: :updated_at, direction: :desc)
    Openjarvis::CursorPage.new(
      scope: scope,
      cursor: params[:cursor],
      limit: limit,
      type: type,
      timestamp_column: timestamp_column,
      direction: direction
    ).perform
  end

  def cursor_type(name, filters = {})
    normalized = filters.to_h.stringify_keys.sort.to_h.transform_values(&:to_s)
    digest = Digest::SHA256.hexdigest(JSON.generate(normalized)).first(16)
    "#{name}:#{digest}"
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

  def enforce_openjarvis_rate_limit!
    result = Openjarvis::RateLimiter.new(hook: openjarvis_hook, bucket: rate_limit_bucket).check
    apply_rate_limit_headers(result)
    return if result.allowed?

    reject_rate_limited_request!(result)
  end

  def apply_rate_limit_headers(result)
    response.set_header('X-RateLimit-Limit', result.limit.to_s)
    response.set_header('X-RateLimit-Remaining', result.remaining.to_s)
    response.set_header('X-RateLimit-Reset', result.reset_at.to_i.to_s)
  end

  def reject_rate_limited_request!(result)
    response.set_header('Retry-After', result.retry_after.to_s)
    raise Openjarvis::ApiError.new(
      'rate_limited',
      'Integration rate limit exceeded',
      status: :too_many_requests,
      details: { retry_after: result.retry_after, limit: result.limit, window_seconds: 60 },
      retryable: true
    )
  end

  def rate_limit_bucket
    request.get? || request.head? ? :read : :write
  end

  def render_openjarvis_error(error)
    render json: error.response_body(request_id: request.request_id), status: error.status
  end

  def render_openjarvis_record_invalid(error)
    render_openjarvis_error(
      Openjarvis::ApiError.new('validation_failed', 'The resource could not be saved', details: error.record.errors.to_hash)
    )
  end

  def render_openjarvis_parameter_missing(error)
    render_openjarvis_error(Openjarvis::ApiError.new('missing_parameter', error.message, status: :bad_request))
  end

  def render_openjarvis_not_found(_error)
    render_openjarvis_error(Openjarvis::ApiError.new('resource_not_found', 'Resource was not found', status: :not_found))
  end

  def render_openjarvis_internal_error(error)
    raise error if Rails.env.test? && request.headers['X-OpenJarvis-Contract-Test'].blank?

    ChatwootExceptionTracker.new(error, account: Current.account, user: Current.user).capture_exception
    result_state = request.get? || request.head? ? 'not_applied' : 'unknown'
    render_openjarvis_error(
      Openjarvis::ApiError.new(
        'internal_error',
        'The operation could not be completed',
        status: :internal_server_error,
        retryable: true,
        result_state: result_state
      )
    )
  end
end
