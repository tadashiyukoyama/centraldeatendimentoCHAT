class Openjarvis::WebhookDelivery < ApplicationRecord
  self.table_name = 'openjarvis_webhook_deliveries'

  belongs_to :integration_hook, class_name: 'Integrations::Hook'

  enum status: { queued: 0, delivering: 1, delivered: 2, failed: 3 }

  validates :delivery_id, presence: true, uniqueness: true
  validates :event_name, presence: true
  validates :payload_digest, presence: true, length: { is: 64 }

  def register_attempt!
    update!(status: :delivering, attempts: attempts + 1, error_code: nil, error_message: nil)
  end

  def mark_delivered!
    update!(status: :delivered, delivered_at: Time.current, response_status: nil)
  end

  def mark_failed!(error)
    update!(
      status: :failed,
      response_status: error.respond_to?(:status) ? error.status : nil,
      error_code: error.class.name.to_s.tr('::', '_').underscore.first(100),
      error_message: error.message.to_s.squish.first(500)
    )
  end

  def record_attempt_error!(error)
    update!(
      response_status: error.respond_to?(:status) ? error.status : nil,
      error_code: error.class.name.to_s.tr('::', '_').underscore.first(100),
      error_message: error.message.to_s.squish.first(500)
    )
  end
end
