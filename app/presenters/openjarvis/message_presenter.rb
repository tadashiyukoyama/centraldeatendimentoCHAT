class Openjarvis::MessagePresenter
  def initialize(message)
    @message = message
  end

  def as_json
    core_attributes.merge(
      delivery: delivery,
      sender: sender,
      attachments: message.attachments.filter_map(&:push_event_data),
      email: email_data,
      unread: unread?
    )
  end

  private

  attr_reader :message

  def core_attributes
    {
      id: message.id,
      conversation_id: message.conversation.display_id,
      message_type: message.message_type,
      content_type: message.content_type,
      content: message.content,
      private: message.private,
      status: message.status,
      reply_to_message_id: message.content_attributes&.dig('in_reply_to'),
      created_at: message.created_at.iso8601,
      updated_at: message.updated_at.iso8601
    }
  end

  def delivery
    result_state = if message.incoming?
                     'received'
                   elsif message.failed?
                     'failed'
                   elsif message.read? || message.delivered?
                     'confirmed'
                   elsif message.source_id.present?
                     'submitted'
                   else
                     'unknown'
                   end
    {
      status: message.status,
      result_state: result_state,
      provider_message_id: message.source_id,
      error: message.external_error.to_s.first(300).presence
    }.compact
  end

  def email_data
    return unless message.inbox.email?

    {
      thread_id: message.conversation.uuid,
      subject: message.conversation.additional_attributes['mail_subject'],
      to: Array(message.content_attributes&.dig('to_emails')),
      cc: Array(message.content_attributes&.dig('cc_emails')),
      bcc: Array(message.content_attributes&.dig('bcc_emails')),
      provider_archive_supported: false,
      provider_trash_supported: false
    }
  end

  def unread?
    return false unless message.incoming?

    seen_at = message.conversation.agent_last_seen_at
    seen_at.blank? || message.created_at > seen_at
  end

  def sender
    return if message.sender.blank?

    {
      id: message.sender.id,
      type: message.sender_type,
      name: message.sender.try(:name),
      email: message.sender.try(:email)
    }.compact
  end
end
