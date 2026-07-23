class Whatsapp::Evolution::IncomingMessageService < Whatsapp::IncomingMessageBaseService
  def initialize(inbox:, params:, outgoing_echo:, provisioning:)
    super(inbox: inbox, params: params, outgoing_echo: outgoing_echo)
    @provisioning = provisioning
  end

  private

  attr_reader :provisioning

  def download_attachment_file(attachment_payload)
    evolution_message = attachment_payload[:evolution_message]
    response = Whatsapp::Evolution::ApiClient.new(provisioning: provisioning).media_base64(message: evolution_message)
    encoded = response.fetch('base64')
    raise ArgumentError unless encoded.is_a?(String)
    raise ArgumentError if encoded.bytesize > maximum_attachment_bytes * 4 / 3 + 4

    decoded = Base64.strict_decode64(encoded)
    raise ArgumentError if decoded.bytesize > maximum_attachment_bytes

    io = StringIO.new(decoded)
    filename =
      response['fileName'].presence ||
      attachment_payload[:filename].presence ||
      "whatsapp-media-#{SecureRandom.hex(4)}"
    content_type =
      response['mimetype'].presence ||
      attachment_payload[:mime_type].presence ||
      'application/octet-stream'
    io.define_singleton_method(:original_filename) { filename }
    io.define_singleton_method(:content_type) { content_type }
    io
  rescue KeyError, ArgumentError => e
    Rails.logger.warn(
      "[EVOLUTION] Media decode failed provisioning_id=#{provisioning.id} error=#{e.class.name}"
    )
    nil
  end

  def maximum_attachment_bytes
    limit_mb = GlobalConfigService.load('MAXIMUM_FILE_UPLOAD_SIZE', 40).to_i
    limit_mb = 40 if limit_mb <= 0
    limit_mb.megabytes
  end
end
