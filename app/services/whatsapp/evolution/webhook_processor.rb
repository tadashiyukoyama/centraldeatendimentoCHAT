class Whatsapp::Evolution::WebhookProcessor
  def initialize(event:, payload:)
    @event = event
    @payload = payload.deep_stringify_keys
    @provisioning = event.provisioning
  end

  def perform
    processing_error = nil

    event.with_lock do
      next if event.processed? || event.ignored?

      event.update!(status: :processing, attempts: event.attempts + 1)
      begin
        outcome = process_event
        event.update!(
          status: outcome,
          processed_at: Time.current,
          last_error_class: nil,
          last_error_message: nil
        )
      rescue StandardError => e
        event.record_failure!(e)
        processing_error = e
      end
    end

    raise processing_error if processing_error
  end

  private

  attr_reader :event, :payload, :provisioning

  def process_event
    case normalized_event_name
    when 'qrcode_updated'
      provisioning.update!(status: :waiting_qr, last_seen_at: Time.current) unless provisioning.connected?
      :processed
    when 'connection_update'
      process_connection_update
    when 'messages_upsert', 'send_message'
      process_message
    when 'messages_update'
      process_message_status
    else
      :ignored
    end
  end

  def normalized_event_name
    payload['event'].to_s.downcase.tr('.', '_')
  end

  def process_connection_update
    data = payload.fetch('data', {})
    case data['state']
    when 'open'
      finalize_connected_instance(data)
    when 'connecting'
      provisioning.update!(status: :connecting, last_seen_at: Time.current)
    when 'close'
      provisioning.update!(status: :disconnected, last_seen_at: Time.current)
    else
      return :ignored
    end
    :processed
  end

  def finalize_connected_instance(data)
    attributes = complete_connection_attributes(connection_attributes(data))
    Whatsapp::Evolution::FinalizeProvisioningService.new(
      provisioning: provisioning,
      **attributes
    ).perform
  end

  def connection_attributes(data)
    {
      connected_number: data['wuid'],
      profile_name: data['profileName'],
      profile_picture_url: data['profilePictureUrl']
    }
  end

  def complete_connection_attributes(attributes)
    return attributes if attributes[:connected_number].present?

    instance = Whatsapp::Evolution::ApiClient.new(provisioning: provisioning).fetch_instance || {}
    {
      connected_number: instance_owner(instance),
      profile_name: attributes[:profile_name] || instance_attribute(instance, 'profileName'),
      profile_picture_url: attributes[:profile_picture_url] || instance_attribute(instance, 'profilePictureUrl')
    }
  end

  def instance_owner(instance)
    instance['ownerJid'] || instance['owner'] || instance.dig('instance', 'ownerJid')
  end

  def instance_attribute(instance, key)
    instance[key] || instance.dig('instance', key)
  end

  def process_message
    synchronize_inbox_if_needed
    return :ignored unless provisioning.inbox

    normalizer = Whatsapp::Evolution::MessageNormalizer.new(data: payload.fetch('data'))
    normalized = normalizer.normalize
    Whatsapp::Evolution::IncomingMessageService.new(
      inbox: provisioning.inbox,
      params: normalized,
      outgoing_echo: normalizer.outgoing_echo?,
      provisioning: provisioning
    ).perform
    :processed
  rescue Whatsapp::Evolution::MessageNormalizer::UnsupportedMessage
    :ignored
  end

  def synchronize_inbox_if_needed
    return if provisioning.inbox
    return if provisioning.failed? || provisioning.deleting? || provisioning.deleted?

    Whatsapp::Evolution::ConnectionSyncService.new(provisioning: provisioning).perform
    provisioning.reload
  end

  def process_message_status
    data = payload.fetch('data', {})
    message_id = data['keyId'] || data['messageId'] || data.dig('key', 'id')
    return :ignored if message_id.blank?

    message = provisioning.inbox&.messages&.find_by(source_id: message_id)
    return :ignored unless message

    status = normalized_message_status(data['status'])
    return :ignored unless status

    message.update!(status: status)
    :processed
  end

  def normalized_message_status(value)
    case value.to_s.upcase
    when 'PENDING', 'SERVER_ACK', 'SENT'
      :sent
    when 'DELIVERY_ACK', 'DELIVERED'
      :delivered
    when 'READ', 'PLAYED'
      :read
    when 'ERROR', 'FAILED'
      :failed
    end
  end
end
