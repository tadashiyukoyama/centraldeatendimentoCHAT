class Openjarvis::Idempotency::Executor
  Result = Data.define(:status, :body, :resource, :replayed)

  KEY_PATTERN = /\A[a-zA-Z0-9][a-zA-Z0-9_.:-]{7,127}\z/

  def initialize(hook:, key:, operation:, payload:)
    @hook = hook
    @key = key.to_s
    @operation = operation.to_s
    @payload = normalize(payload)
    @request_digest = Digest::SHA256.hexdigest(JSON.generate(@payload))
  end

  def execute
    validate_key!

    result = nil
    Openjarvis::ApiRequest.transaction do
      request = create_request
      result = yield
      complete_request(request, result)
    end
    Result.new(status: result.status, body: result.body, resource: result.resource, replayed: false)
  rescue ActiveRecord::RecordNotUnique
    replay_existing
  end

  private

  attr_reader :hook, :key, :operation, :payload, :request_digest

  def validate_key!
    return if KEY_PATTERN.match?(key)

    raise Openjarvis::ApiError.new(
      'invalid_idempotency_key',
      'Idempotency-Key must contain 8 to 128 letters, numbers, dots, colons, underscores or hyphens',
      status: :bad_request
    )
  end

  def create_request
    hook.openjarvis_api_requests.create!(
      idempotency_key: key,
      operation: operation,
      request_digest: request_digest
    )
  end

  def complete_request(request, result)
    request.update!(
      status: :completed,
      response_status: result.status,
      response_body: JSON.generate(result.body),
      resource_type: result.resource&.class&.base_class&.name,
      resource_id: result.resource&.id,
      completed_at: Time.current
    )
  end

  def replay_existing
    request = hook.openjarvis_api_requests.find_by!(idempotency_key: key)
    if request.request_digest != request_digest || request.operation != operation
      raise Openjarvis::ApiError.new(
        'idempotency_conflict',
        'This Idempotency-Key was already used with a different request',
        status: :conflict
      )
    end

    unless request.completed?
      raise Openjarvis::ApiError.new(
        'request_in_progress',
        'A request with this Idempotency-Key is still processing; reconcile before retrying with another key',
        status: :conflict,
        retryable: true,
        result_state: 'unknown'
      )
    end

    Result.new(status: request.response_status, body: request.parsed_response_body, resource: nil, replayed: true)
  end

  def normalize(value)
    object = value.respond_to?(:to_unsafe_h) ? value.to_unsafe_h : value
    case object
    when Hash
      object.to_h.stringify_keys.sort.to_h.transform_values { |item| normalize(item) }
    when Array
      object.map { |item| normalize(item) }
    when Time, DateTime
      object.iso8601
    else
      object
    end
  end
end
