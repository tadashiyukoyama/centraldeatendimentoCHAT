class Openjarvis::WebhookEnqueuer
  def initialize(account:, event_name:, resource:, changed_attributes: nil)
    @account = account
    @event_name = event_name
    @resource = resource
    @changed_attributes = changed_attributes
  end

  def perform
    return unless deliverable?

    delivery_id = SecureRandom.uuid
    event_id = SecureRandom.uuid
    sequence = Openjarvis::ResourceSequence.next_for!(hook: hook, resource: resource)
    payload = webhook_payload(event_id, sequence)
    delivery = create_delivery(payload, delivery_id, event_id, sequence)
    Openjarvis::WebhookDeliveryJob.perform_later(delivery.id, payload)
  end

  private

  attr_reader :account, :event_name, :resource, :changed_attributes

  def hook
    @hook ||= account.hooks.enabled.find_by(app_id: Openjarvis::Configuration::APP_ID)
  end

  def deliverable?
    return false unless hook

    configuration = hook.openjarvis_configuration
    configuration.valid? && configuration.webhooks_enabled? &&
      configuration.subscriptions.include?(event_name) && Openjarvis::AccessScope.new(hook).accessible?(resource)
  end

  def webhook_payload(event_id, sequence)
    Openjarvis::WebhookPayloadBuilder.new(
      event_name: event_name,
      resource: resource,
      event_id: event_id,
      resource_sequence: sequence,
      changed_attributes: changed_attributes
    ).as_json
  end

  def create_delivery(payload, delivery_id, event_id, sequence)
    identity = Openjarvis::ResourceIdentity.new(resource, sequence: sequence)
    hook.openjarvis_webhook_deliveries.create!(
      delivery_id: delivery_id,
      event_id: event_id,
      event_name: event_name,
      resource_type: resource.class.base_class.name,
      resource_id: resource.id,
      resource_version: identity.version,
      resource_sequence: sequence,
      payload_digest: Digest::SHA256.hexdigest(JSON.generate(payload))
    )
  end
end
