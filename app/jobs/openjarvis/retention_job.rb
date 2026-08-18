class Openjarvis::RetentionJob < ApplicationJob
  queue_as :purgable

  def perform
    Openjarvis::ApiRequest.expired.in_batches.delete_all
    Openjarvis::WebhookDelivery.expired.in_batches.delete_all
    clear_expired_credential_overlap
  end

  private

  def clear_expired_credential_overlap
    Integrations::Hook.where(app_id: Openjarvis::Configuration::APP_ID)
                      .where('previous_access_token_expires_at < :now OR previous_webhook_secret_expires_at < :now', now: Time.current)
                      .find_each do |hook|
      attributes = {}
      if hook.previous_access_token_expires_at&.past?
        attributes[:previous_access_token] = nil
        attributes[:previous_access_token_expires_at] = nil
      end
      if hook.previous_webhook_secret_expires_at&.past?
        attributes[:previous_webhook_secret] = nil
        attributes[:previous_webhook_secret_expires_at] = nil
      end
      hook.update!(attributes) if attributes.any?
    end
  end
end
