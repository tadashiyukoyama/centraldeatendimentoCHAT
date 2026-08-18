class Openjarvis::MessagePresenter
  def initialize(message)
    @message = message
  end

  def as_json
    {
      id: message.id,
      conversation_id: message.conversation.display_id,
      message_type: message.message_type,
      content_type: message.content_type,
      content: message.content,
      private: message.private,
      status: message.status,
      sender: sender,
      attachments: message.attachments.filter_map(&:push_event_data),
      created_at: message.created_at.iso8601,
      updated_at: message.updated_at.iso8601
    }
  end

  private

  attr_reader :message

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
