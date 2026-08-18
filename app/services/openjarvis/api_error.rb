class Openjarvis::ApiError < StandardError
  attr_reader :code, :details, :status

  def initialize(code, message, status: :unprocessable_entity, details: nil)
    @code = code.to_s
    @status = Rack::Utils.status_code(status)
    @details = details
    super(message)
  end

  def response_body
    { error: { code: code, message: message, details: details }.compact }
  end
end
