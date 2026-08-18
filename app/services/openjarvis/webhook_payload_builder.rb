class Openjarvis::WebhookPayloadBuilder
  def initialize(event_name:, resource:, changed_attributes: nil)
    @event_name = event_name
    @resource = resource
    @changed_attributes = changed_attributes
  end

  def as_json
    {
      event: event_name,
      occurred_at: Time.current.iso8601,
      data: presented_resource,
      changed_attributes: changed_attributes
    }.compact
  end

  private

  attr_reader :event_name, :resource, :changed_attributes

  def presented_resource
    case resource
    when Message
      Openjarvis::MessagePresenter.new(resource).as_json
    when Conversation
      Openjarvis::ConversationPresenter.new(resource).as_json
    when Contact
      Openjarvis::ContactPresenter.new(resource).as_json
    else
      raise ArgumentError, "Unsupported OpenJarvis webhook resource: #{resource.class.name}"
    end
  end
end
