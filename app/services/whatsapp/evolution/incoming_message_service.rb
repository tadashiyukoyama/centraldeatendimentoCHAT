class Whatsapp::Evolution::IncomingMessageService < Whatsapp::IncomingMessageBaseService
  def initialize(inbox:, params:, outgoing_echo:, provisioning:)
    super(inbox: inbox, params: params, outgoing_echo: outgoing_echo)
    @provisioning = provisioning
  end

  private

  attr_reader :provisioning

  def download_attachment_file(attachment_payload)
    response = api_client.media_base64(message: attachment_payload[:evolution_message])
    decoded = decode_media(response.fetch('base64'))
    attachment_io(decoded, response, attachment_payload)
  rescue KeyError, ArgumentError => e
    Rails.logger.warn(
      "[EVOLUTION] Media decode failed provisioning_id=#{provisioning.id} error=#{e.class.name}"
    )
    nil
  end

  def api_client
    @api_client ||= Whatsapp::Evolution::ApiClient.new(provisioning: provisioning)
  end

  def decode_media(encoded)
    raise ArgumentError unless encoded.is_a?(String)
    raise ArgumentError if encoded.bytesize > maximum_encoded_attachment_bytes

    decoded = Base64.strict_decode64(encoded)
    raise ArgumentError if decoded.bytesize > maximum_attachment_bytes

    decoded
  end

  def attachment_io(decoded, response, attachment_payload)
    filename = response['fileName'].presence || attachment_payload[:filename].presence || generated_filename
    content_type = response['mimetype'].presence || attachment_payload[:mime_type].presence || 'application/octet-stream'

    StringIO.new(decoded).tap do |io|
      io.define_singleton_method(:original_filename) { filename }
      io.define_singleton_method(:content_type) { content_type }
    end
  end

  def generated_filename
    "whatsapp-media-#{SecureRandom.hex(4)}"
  end

  def maximum_encoded_attachment_bytes
    ((maximum_attachment_bytes * 4) / 3) + 4
  end

  def find_message_by_source_id(source_id)
    return unless source_id

    @message = @inbox.messages.find_by(source_id: source_id)
  end

  def lock_message_source_id!
    return false if messages_data.blank?

    lock_id = "evolution:#{@inbox.id}:#{messages_data.first[:id]}"
    Whatsapp::MessageDedupLock.new(lock_id).acquire!
  end

  def maximum_attachment_bytes
    limit_mb = GlobalConfigService.load('MAXIMUM_FILE_UPLOAD_SIZE', 40).to_i
    limit_mb = 40 if limit_mb <= 0
    limit_mb.megabytes
  end
end
