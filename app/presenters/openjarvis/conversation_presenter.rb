class Openjarvis::ConversationPresenter
  def initialize(conversation, include_last_message: true)
    @conversation = conversation
    @include_last_message = include_last_message
  end

  def as_json
    conversation_data.tap do |data|
      last_message = presented_last_message
      data[:last_message] = last_message if last_message
    end
  end

  private

  attr_reader :conversation

  def conversation_data
    {
      id: conversation.display_id,
      internal_id: conversation.id,
      status: conversation.status,
      priority: conversation.priority,
      **relationship_data,
      **attribute_data,
      **timestamp_data
    }
  end

  def relationship_data
    {
      inbox: Openjarvis::InboxPresenter.new(conversation.inbox).as_json,
      contact: conversation.contact ? Openjarvis::ContactPresenter.new(conversation.contact).as_json : nil,
      assignee: user_data(conversation.assignee),
      team: conversation.team&.slice(:id, :name)
    }
  end

  def attribute_data
    {
      labels: conversation.label_list,
      additional_attributes: conversation.additional_attributes || {},
      custom_attributes: conversation.custom_attributes || {}
    }
  end

  def timestamp_data
    {
      last_activity_at: conversation.last_activity_at&.iso8601,
      created_at: conversation.created_at.iso8601,
      updated_at: conversation.updated_at.iso8601
    }
  end

  def presented_last_message
    return unless @include_last_message

    last_message = conversation.messages.reorder(created_at: :desc).first
    Openjarvis::MessagePresenter.new(last_message).as_json if last_message
  end

  def user_data(user)
    user&.slice(:id, :name, :email)
  end
end
