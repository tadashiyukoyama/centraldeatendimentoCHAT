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
        client.send_text(
          number: phone_number,
          text: message.outgoing_content.to_s,
          quoted: quoted_payload(phone_number, message)
        )
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
    return false if provisioning.blank?
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

  def send_reaction(phone_number:, message:, reaction:)
    client.send_reaction(
      message_key: provider_message_key(phone_number, message),
      reaction: reaction
    )
  end

  def mark_messages_read(phone_number:, messages:)
    keys = messages.map { |message| provider_message_key(phone_number, message) }
    client.mark_messages_read(message_keys: keys)
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
      file_name: media_type == 'document' ? attachment.file.filename.to_s : nil,
      quoted: quoted_payload(phone_number, message)
    )
  end

  def quoted_payload(phone_number, message)
    external_id = message.content_attributes['in_reply_to_external_id']
    return if external_id.blank?

    target = message.conversation.messages.find_by(source_id: external_id)
    return if target.blank?

    {
      key: provider_message_key(phone_number, target),
      message: { conversation: target.content.presence || quoted_attachment_label(target) }
    }
  end

  def provider_message_key(phone_number, message)
    raise Whatsapp::Evolution::ApiClient::Error.new(
      'WhatsApp message does not have a provider identifier',
      code: 'missing_provider_message_id'
    ) if message.source_id.blank?

    {
      remoteJid: "#{normalized_number(phone_number)}@s.whatsapp.net",
      fromMe: message.outgoing?,
      id: message.source_id
    }
  end

  def normalized_number(number)
    number.to_s.gsub(/\D/, '')
  end

  def quoted_attachment_label(message)
    attachment = message.attachments.first
    attachment ? "[#{attachment.file_type}]" : '[mensagem]'
  end
end
