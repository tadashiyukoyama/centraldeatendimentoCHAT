class Openjarvis::WebhookDeliveryJob < ApplicationJob
  queue_as :medium

  retry_on Openjarvis::WebhookClient::DeliveryError, wait: :polynomially_longer, attempts: 5 do |job, error|
    delivery = Openjarvis::WebhookDelivery.find_by(id: job.arguments.first)
    delivery&.mark_failed!(error)
  end

  discard_on ActiveRecord::RecordNotFound

  def perform(delivery_id, payload)
    delivery = Openjarvis::WebhookDelivery.find(delivery_id)
    hook = delivery.integration_hook
    return delivery.mark_failed!(Openjarvis::WebhookClient::DeliveryError.new('Integration is disabled')) unless deliverable?(hook)

    delivery.register_attempt!
    configuration = hook.openjarvis_configuration
    client = Openjarvis::WebhookClient.new(endpoint_url: configuration.endpoint_url, secrets: hook.active_openjarvis_webhook_secrets)
    client.deliver(payload, delivery_id: delivery.delivery_id)
    delivery.mark_delivered!
  rescue Openjarvis::WebhookClient::DeliveryError => e
    if e.retryable?
      delivery&.record_attempt_error!(e, next_attempt_at: estimated_next_attempt(delivery))
      raise
    end

    delivery&.mark_failed!(e)
  end

  private

  def deliverable?(hook)
    hook.enabled? && hook.openjarvis_configuration.valid? && hook.openjarvis_configuration.webhooks_enabled?
  end

  def estimated_next_attempt(delivery)
    [(delivery&.attempts.to_i**4) + 2, 6.hours.to_i].min.seconds.from_now
  end
end
