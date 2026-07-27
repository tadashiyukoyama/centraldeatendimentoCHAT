class Instagram::CommentAutomation::ApiClient
  Result = Data.define(:success?, :transient?, :status, :body, :error_code, :error_type)
  ID_PATTERN = /\A\d+\z/
  TRANSIENT_GRAPH_ERROR_CODES = %w[1 2 4 17 32 613].freeze

  def initialize(channel)
    @channel = channel
  end

  def reply_publicly(comment_id:, text:)
    validate_id!(comment_id)
    post("/#{comment_id}/replies", { message: text })
  end

  def reply_privately(comment_id:, text:)
    validate_id!(comment_id)
    post(
      "/#{instagram_id}/messages",
      {
        recipient: { comment_id: comment_id.to_s },
        message: { text: text }
      }
    )
  end

  def subscribed_fields
    response = request(:get, "/#{instagram_id}/subscribed_apps")
    return response unless response.success?

    fields = Array(response.body['data']).flat_map { |subscription| Array(subscription['subscribed_fields']) }.uniq.sort
    Result.new(success?: true, transient?: false, status: response.status, body: { 'subscribed_fields' => fields },
               error_code: nil, error_type: nil)
  end

  def subscribe(fields:)
    post("/#{instagram_id}/subscribed_apps", { subscribed_fields: fields })
  end

  private

  def post(path, payload)
    request(:post, path, payload)
  end

  def request(method, path, payload = nil)
    response = HTTParty.public_send(
      method,
      "#{base_url}#{path}",
      headers: request_headers,
      body: payload&.to_json,
      timeout: 15
    )
    build_result(response)
  rescue Timeout::Error, SocketError => e
    network_failure(e)
  end

  def build_result(response)
    parsed = parse_body(response.body)
    error = parsed['error'].is_a?(Hash) ? parsed['error'] : {}

    Result.new(
      success?: response.success? && error.blank?,
      transient?: transient_failure?(response.code, error),
      status: response.code,
      body: parsed,
      error_code: error['code']&.to_s || response.code.to_s,
      error_type: error['type'].presence
    )
  end

  def network_failure(error)
    Result.new(
      success?: false,
      transient?: true,
      status: nil,
      body: {},
      error_code: error.class.name,
      error_type: 'network_error'
    )
  end

  def request_headers
    {
      'Accept' => 'application/json',
      'Authorization' => "Bearer #{access_token}",
      'Content-Type' => 'application/json'
    }
  end

  def transient_failure?(status, error)
    status = status.to_i
    status == 429 ||
      status >= 500 ||
      error['is_transient'] == true ||
      TRANSIENT_GRAPH_ERROR_CODES.include?(error['code'].to_s)
  end

  def parse_body(body)
    JSON.parse(body.presence || '{}')
  rescue JSON::ParserError
    {}
  end

  def base_url
    "https://#{graph_host}/#{api_version}"
  end

  def graph_host
    @channel.is_a?(Channel::Instagram) ? 'graph.instagram.com' : 'graph.facebook.com'
  end

  def api_version
    GlobalConfigService.load('INSTAGRAM_API_VERSION', 'v22.0')
  end

  def instagram_id
    validate_id!(@channel.instagram_id)
  end

  def access_token
    return @channel.access_token if @channel.is_a?(Channel::Instagram)

    @channel.page_access_token
  end

  def validate_id!(value)
    return value.to_s if value.to_s.match?(ID_PATTERN)

    raise ArgumentError, 'Invalid Instagram object identifier'
  end
end
