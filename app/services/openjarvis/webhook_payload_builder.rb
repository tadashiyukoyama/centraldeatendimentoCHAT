class Openjarvis::WebhookPayloadBuilder
  def initialize(event_name:, resource:, event_id:, resource_sequence:, changed_attributes: nil)
    @event_name = event_name
    @resource = resource
    @event_id = event_id
    @resource_sequence = resource_sequence
    @changed_attributes = changed_attributes
  end

  def as_json
    {
      schema_version: Openjarvis::Configuration::SCHEMA_VERSION,
      event_id: event_id,
      event: event_name,
      occurred_at: Time.current.utc.iso8601(6),
      resource: Openjarvis::ResourceIdentity.new(resource, sequence: resource_sequence).as_json,
      data: presented_resource,
      changed_attributes: changed_attributes
    }.compact
  end

  private

  attr_reader :event_name, :resource, :event_id, :resource_sequence, :changed_attributes

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
