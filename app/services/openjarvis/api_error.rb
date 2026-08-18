class Openjarvis::ApiError < StandardError
  attr_reader :code, :details, :status, :retryable, :result_state

  def initialize(code, message, status: :unprocessable_entity, details: nil, **options)
    @code = code.to_s
    @status = Rack::Utils.status_code(status)
    @details = details
    @retryable = options.fetch(:retryable, false)
    @result_state = options.fetch(:result_state, 'not_applied')
    super(message)
  end

  def response_body(request_id: nil)
    {
      error: {
        code: code,
        message: message,
        details: details,
        retryable: retryable,
        result_state: result_state,
        request_id: request_id
      }.compact
    }
  end
end
