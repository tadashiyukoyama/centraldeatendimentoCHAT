class Openjarvis::WebhookClient
  class DeliveryError < StandardError
    attr_reader :status

    def initialize(message, status: nil)
      @status = status
      super(message)
    end
  end

  def initialize(endpoint_url:, secret:)
    @endpoint_url = endpoint_url
    @secret = secret
  end

  def deliver(payload, delivery_id: SecureRandom.uuid)
    body = JSON.generate(payload)
    timestamp = Time.current.to_i.to_s
    SafeFetch.fetch(
      endpoint_url,
      method: :post,
      body: body,
      headers: headers(body, timestamp, delivery_id),
      sensitive_headers: %w[x-acelerachat-delivery x-acelerachat-timestamp x-acelerachat-signature],
      open_timeout: 3,
      read_timeout: 10,
      max_bytes: 1.megabyte,
      validate_content_type: false
    ) { |_result| true }
  rescue SafeFetch::HttpError => e
    status = e.message.to_s[/\A(\d{3})\b/, 1]&.to_i
    raise DeliveryError.new("OpenJarvis returned HTTP #{status || 'error'}", status: status)
  rescue SafeFetch::Error => e
    raise DeliveryError, e.class.name
  end

  private

  attr_reader :endpoint_url, :secret

  def headers(body, timestamp, delivery_id)
    signature = OpenSSL::HMAC.hexdigest('SHA256', secret, "#{timestamp}.#{body}")
    {
      'Accept' => 'application/json',
      'Content-Type' => 'application/json',
      'User-Agent' => "AceleraChat-OpenJarvis/#{Chatwoot.config[:version]}",
      'X-AceleraChat-Delivery' => delivery_id,
      'X-AceleraChat-Timestamp' => timestamp,
      'X-AceleraChat-Signature' => "sha256=#{signature}"
    }
  end
end
