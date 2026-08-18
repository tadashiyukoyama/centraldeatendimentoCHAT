class Openjarvis::WebhookDelivery < ApplicationRecord
  RETENTION_PERIOD = 30.days
  self.table_name = 'openjarvis_webhook_deliveries'

  belongs_to :integration_hook, class_name: 'Integrations::Hook'

  enum status: { queued: 0, delivering: 1, delivered: 2, failed: 3 }

  validates :delivery_id, presence: true, uniqueness: true
  validates :event_id, presence: true, uniqueness: true
  validates :event_name, presence: true
  validates :payload_digest, presence: true, length: { is: 64 }
  validates :schema_version, presence: true
  validates :resource_sequence, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  before_validation :set_expiration, on: :create

  scope :expired, -> { where(expires_at: ...Time.current) }

  def register_attempt!
    update!(status: :delivering, attempts: attempts + 1, error_code: nil, error_message: nil, failure_class: nil, next_attempt_at: nil)
  end

  def mark_delivered!
    update!(status: :delivered, delivered_at: Time.current, response_status: nil)
  end

  def mark_failed!(error)
    update!(
      status: :failed,
      response_status: error.respond_to?(:status) ? error.status : nil,
      error_code: error.class.name.to_s.tr('::', '_').underscore.first(100),
      error_message: error.message.to_s.squish.first(500),
      failure_class: error.respond_to?(:failure_class) ? error.failure_class : 'permanent',
      next_attempt_at: nil
    )
  end

  def record_attempt_error!(error, next_attempt_at: nil)
    update!(
      response_status: error.respond_to?(:status) ? error.status : nil,
      error_code: error.class.name.to_s.tr('::', '_').underscore.first(100),
      error_message: error.message.to_s.squish.first(500),
      failure_class: error.respond_to?(:failure_class) ? error.failure_class : 'temporary',
      next_attempt_at: next_attempt_at
    )
  end

  private

  def set_expiration
    self.expires_at ||= RETENTION_PERIOD.from_now
  end
end
