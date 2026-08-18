class Openjarvis::WebhookClient
  class DeliveryError < StandardError
    attr_reader :status, :failure_class

    def initialize(message, status: nil, failure_class: nil)
      @status = status
      @failure_class = failure_class || self.class.classify(status)
      super(message)
    end

    def retryable?
      failure_class == 'temporary'
    end

    def self.classify(status)
      value = status.to_i
      return 'temporary' if status.nil? || value == 408 || value == 409 || value == 425 || value == 429 || value >= 500

      'permanent'
    end
  end

  def initialize(endpoint_url:, secrets:)
    @endpoint_url = endpoint_url
    @secrets = Array(secrets).compact
  end

  def deliver(payload, delivery_id: SecureRandom.uuid)
    body = JSON.generate(payload)
    timestamp = Time.current.to_i.to_s
    perform_delivery(body, timestamp, delivery_id)
  rescue SafeFetch::HttpError => e
    handle_http_error(e)
  rescue SafeFetch::Error => e
    raise DeliveryError, e.class.name
  end

  private

  attr_reader :endpoint_url, :secrets

  def perform_delivery(body, timestamp, delivery_id)
    SafeFetch.fetch(
      endpoint_url,
      method: :post,
      body: body,
      headers: headers(body, timestamp, delivery_id),
      sensitive_headers: %w[
        x-acelerachat-delivery x-acelerachat-timestamp x-acelerachat-signature
        x-acelerachat-signature-previous
      ],
      open_timeout: 3,
      read_timeout: 10,
      max_bytes: 1.megabyte,
      validate_content_type: false
    ) { |_result| true }
  end

  def handle_http_error(error)
    status = error.message.to_s[/\A(\d{3})\b/, 1]&.to_i
    raise DeliveryError.new("OpenJarvis returned HTTP #{status || 'error'}", status: status)
  end

  def headers(body, timestamp, delivery_id)
    values = secrets.map { |secret| "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', secret, "#{timestamp}.#{body}")}" }
    result = {
      'Accept' => 'application/json',
      'Content-Type' => 'application/json',
      'User-Agent' => "AceleraChat-OpenJarvis/#{Chatwoot.config[:version]}",
      'X-AceleraChat-Delivery' => delivery_id,
      'X-AceleraChat-Timestamp' => timestamp,
      'X-AceleraChat-Signature' => values.first
    }
    result['X-AceleraChat-Signature-Previous'] = values.second if values.second
    result
  end
end
