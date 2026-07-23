class Whatsapp::Evolution::ApiClient
  class Error < StandardError
    attr_reader :code, :http_status

    def initialize(message, code:, http_status: nil)
      super(message)
      @code = code
      @http_status = http_status
    end
  end

  def initialize(provisioning: nil)
    @provisioning = provisioning
  end

  def create_instance
    request(
      :post,
      '/instance/create',
      body: {
        instanceName: provisioning.instance_name,
        token: provisioning.instance_token,
        qrcode: true,
        integration: 'WHATSAPP-BAILEYS',
        webhook: webhook_configuration
      },
      global_key: true
    )
  end

  def connect
    request(:get, "/instance/connect/#{escaped_instance_name}")
  end

  def connection_state
    request(:get, "/instance/connectionState/#{escaped_instance_name}")
  end

  def fetch_instance
    response = request(:get, "/instance/fetchInstances?instanceName=#{escaped_instance_name}", global_key: true)
    response.is_a?(Array) ? response.first : response
  end

  def logout
    request(:delete, "/instance/logout/#{escaped_instance_name}")
  end

  def delete_instance
    request(:delete, "/instance/delete/#{escaped_instance_name}", global_key: true)
  end

  def send_text(number:, text:)
    request(
      :post,
      "/message/sendText/#{escaped_instance_name}",
      body: { number: normalized_number(number), text: text }
    )
  end

  def send_media(number:, media:, media_type:, mime_type:, caption: nil, file_name: nil)
    request(
      :post,
      "/message/sendMedia/#{escaped_instance_name}",
      body: {
        number: normalized_number(number),
        mediatype: media_type,
        mimetype: mime_type,
        caption: caption,
        fileName: file_name,
        media: media
      }.compact
    )
  end

  def media_base64(message:)
    request(
      :post,
      "/chat/getBase64FromMediaMessage/#{escaped_instance_name}",
      body: { message: message }
    )
  end

  private

  attr_reader :provisioning

  def request(method, path, body: nil, global_key: false)
    Whatsapp::Evolution::Configuration.validate!
    response = HTTParty.public_send(
      method,
      "#{Whatsapp::Evolution::Configuration.api_url}#{path}",
      request_options(body: body, global_key: global_key)
    )
    raise_http_error!(response) unless response.success?

    parsed_response(response)
  rescue Whatsapp::Evolution::Configuration::ConfigurationError
    raise
  rescue Error
    raise
  rescue StandardError
    raise Error.new(
      'Evolution API is unavailable',
      code: 'evolution_unavailable'
    )
  end

  def request_options(body:, global_key:)
    options = {
      headers: {
        'Content-Type' => 'application/json',
        'Accept' => 'application/json',
        'apikey' => authentication_key(global_key)
      },
      timeout: 15,
      verify: true
    }
    options[:body] = body.to_json if body
    basic_auth = Whatsapp::Evolution::Configuration.basic_auth
    options[:basic_auth] = basic_auth if basic_auth
    options
  end

  def authentication_key(global_key)
    return Whatsapp::Evolution::Configuration.api_key if global_key
    if provisioning&.instance_token.blank?
      raise Error.new(
        'Evolution instance credential is unavailable',
        code: 'missing_instance_credential'
      )
    end

    provisioning.instance_token
  end

  def parsed_response(response)
    return {} if response.body.blank?

    parsed = response.parsed_response
    parsed.is_a?(String) ? { 'message' => parsed } : parsed
  end

  def raise_http_error!(response)
    raise Error.new(
      "Evolution API request failed with HTTP #{response.code}",
      code: "evolution_http_#{response.code}",
      http_status: response.code
    )
  end

  def escaped_instance_name
    ERB::Util.url_encode(provisioning.instance_name)
  end

  def normalized_number(number)
    digits = number.to_s.gsub(/\D/, '')
    unless digits.match?(/\A\d{6,15}\z/)
      raise Error.new(
        'WhatsApp destination number is invalid',
        code: 'invalid_destination'
      )
    end

    digits
  end

  def webhook_configuration
    {
      enabled: true,
      url: Whatsapp::Evolution::Configuration.webhook_url(provisioning.public_id),
      webhookByEvents: false,
      webhookBase64: false,
      events: %w[QRCODE_UPDATED CONNECTION_UPDATE MESSAGES_UPSERT MESSAGES_UPDATE SEND_MESSAGE],
      headers: { jwt_key: provisioning.webhook_secret }
    }
  end
end
