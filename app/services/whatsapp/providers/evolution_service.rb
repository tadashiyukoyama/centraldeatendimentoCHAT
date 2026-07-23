class Whatsapp::Providers::EvolutionService < Whatsapp::Providers::BaseService
  def supports_templates?
    false
  end

  def session_window_enforced?
    false
  end

  def send_message(phone_number, message)
    response =
      if message.attachments.present?
        send_attachment(phone_number, message)
      else
        client.send_text(number: phone_number, text: message.outgoing_content.to_s)
      end

    response.dig('key', 'id') || response['id'] || response.dig('message', 'key', 'id')
  rescue Whatsapp::Evolution::ApiClient::Error => e
    message.update!(status: :failed, external_error: e.message)
    nil
  end

  def send_template(_phone_number, _template_info, message)
    message.update!(status: :failed, external_error: 'Templates are not supported by the Evolution WhatsApp provider')
    nil
  end

  def sync_templates
    # rubocop:disable Rails/SkipsModelValidations
    whatsapp_channel.update_columns(message_templates: [], message_templates_last_updated: Time.current)
    # rubocop:enable Rails/SkipsModelValidations
    true
  end

  def validate_provider_config?
    return false unless provisioning.present?
    return false unless provisioning.account_id == whatsapp_channel.account_id
    return false unless provisioning.connected?

    provisioning.whatsapp_channel_id == whatsapp_channel.id ||
      bootstrap_validation_context?
  end

  def media_url(_media_id)
    nil
  end

  def api_headers
    {}
  end

  private

  def provisioning
    @provisioning ||= Whatsapp::EvolutionProvisioning.find_by(
      id: whatsapp_channel.provider_config['evolution_provisioning_id']
    )
  end

  def client
    @client ||= Whatsapp::Evolution::ApiClient.new(provisioning: provisioning)
  end

  def bootstrap_validation_context?
    whatsapp_channel.new_record? &&
      provisioning.whatsapp_channel_id.nil? &&
      whatsapp_channel.evolution_provisioning_validation_id.to_i == provisioning.id
  end

  def send_attachment(phone_number, message)
    attachment = message.attachments.first
    media_type = %w[image audio video].include?(attachment.file_type) ? attachment.file_type : 'document'
    client.send_media(
      number: phone_number,
      media: attachment.download_url,
      media_type: media_type,
      mime_type: attachment.file.blob.content_type,
      caption: %w[audio sticker].include?(media_type) ? nil : message.outgoing_content,
      file_name: media_type == 'document' ? attachment.file.filename.to_s : nil
    )
  end
end
