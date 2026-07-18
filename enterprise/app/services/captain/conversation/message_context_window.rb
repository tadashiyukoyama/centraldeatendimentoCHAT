class Captain::Conversation::MessageContextWindow
  MESSAGE_TYPES = %i[incoming outgoing activity].freeze

  def initialize(conversation)
    @conversation = conversation
  end

  def perform
    messages = @conversation.messages
                               .where(private: false, message_type: MESSAGE_TYPES)
                               .reorder(created_at: :asc, id: :asc)
                               .to_a

    boundary_index = messages.rindex { |message| resolution_activity?(message) }
    return messages if boundary_index.nil?

    messages[(boundary_index + 1)..] || []
  end

  private

  def resolution_activity?(message)
    return false unless message.activity?

    activity = message.content_attributes.to_h['activity'].to_h
    activity['type'] == 'conversation_status_changed' && activity['status'] == 'resolved'
  end
end
