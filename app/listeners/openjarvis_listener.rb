class OpenjarvisListener < BaseListener
  EVENT_NAMES = {
    message_created: 'message.created',
    message_updated: 'message.updated',
    conversation_created: 'conversation.created',
    conversation_updated: 'conversation.updated',
    conversation_status_changed: 'conversation.status_changed',
    contact_created: 'contact.created',
    contact_updated: 'contact.updated'
  }.freeze

  EVENT_NAMES.each_key do |method_name|
    define_method(method_name) do |event|
      resource = resource_for(method_name, event)
      Openjarvis::WebhookEnqueuer.new(
        account: resource.account,
        event_name: EVENT_NAMES.fetch(method_name),
        resource: resource,
        changed_attributes: extract_changed_attributes(event)
      ).perform
    end
  end

  private

  def resource_for(method_name, event)
    case method_name
    when :message_created, :message_updated
      event.data[:message]
    when :conversation_created, :conversation_updated, :conversation_status_changed
      event.data[:conversation]
    when :contact_created, :contact_updated
      event.data[:contact]
    end
  end
end
