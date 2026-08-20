class Openjarvis::WhatsappActionService
  MAX_READ_RECEIPTS = 100

  def initialize(conversation:)
    @conversation = conversation
  end

  def react(message:, reaction:)
    validate_capability!('messages.reaction')
    validate_message!(message)
    provider_service.send_reaction(
      phone_number: contact_number,
      message: message,
      reaction: reaction
    )
    {
      conversation_id: conversation.display_id,
      message_id: message.id,
      reaction: reaction,
      provider: 'evolution',
      result_state: 'applied'
    }
  rescue Whatsapp::Evolution::ApiClient::Error => e
    raise provider_error(e)
  end

  def mark_read
    validate_capability!('messages.mark_read_provider')
    messages = provider_read_messages
    validate_provider_messages!(messages)
    provider_service.mark_messages_read(phone_number: contact_number, messages: messages)
    read_at = messages.map(&:created_at).max
    conversation.update!(agent_last_seen_at: [conversation.agent_last_seen_at, read_at].compact.max)
    provider_read_result(messages, read_at)
  rescue Whatsapp::Evolution::ApiClient::Error => e
    raise provider_error(e)
  end

  private

  attr_reader :conversation

  def validate_capability!(capability)
    resolver = Openjarvis::CapabilityResolver.new(inbox: conversation.inbox)
    unless resolver.supported?(capability)
      raise Openjarvis::ApiError.new(
        'capability_not_supported',
        'This provider operation is not supported for the selected inbox',
        status: :unprocessable_entity,
        details: { capability: capability, inbox_id: conversation.inbox_id }
      )
    end
    return if resolver.connection[:operational]

    raise Openjarvis::ApiError.new(
      'source_disconnected',
      'The selected WhatsApp inbox is not connected',
      status: :conflict,
      details: { inbox_id: conversation.inbox_id },
      retryable: true
    )
  end

  def validate_message!(message)
    return if message.source_id.present?

    raise Openjarvis::ApiError.new(
      'provider_message_id_missing',
      'The selected message does not have a provider identifier',
      status: :unprocessable_entity
    )
  end

  def provider_read_messages
    conversation.messages.incoming.where.not(source_id: nil).reorder(id: :desc).limit(MAX_READ_RECEIPTS).to_a
  end

  def validate_provider_messages!(messages)
    return if messages.any?

    raise Openjarvis::ApiError.new(
      'provider_messages_not_found',
      'No provider messages are available to mark as read',
      status: :unprocessable_entity
    )
  end

  def provider_read_result(messages, read_at)
    {
      conversation_id: conversation.display_id,
      read_at: read_at.iso8601,
      provider_receipt_sent: true,
      provider: 'evolution',
      message_count: messages.size,
      result_state: 'applied'
    }
  end

  def contact_number
    conversation.contact_inbox.source_id
  end

  def provider_service
    conversation.inbox.channel.provider_service
  end

  def provider_error(error)
    unknown = error.http_status.blank? || error.http_status.to_i >= 500
    Openjarvis::ApiError.new(
      unknown ? 'external_result_unknown' : 'provider_rejected',
      unknown ? 'The provider did not confirm the operation result' : 'The provider rejected the operation',
      status: unknown ? :bad_gateway : :unprocessable_entity,
      details: { provider: 'evolution', provider_code: error.code },
      retryable: unknown,
      result_state: unknown ? 'unknown' : 'not_applied'
    )
  end
end
