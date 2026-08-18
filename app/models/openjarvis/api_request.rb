class Openjarvis::ApiRequest < ApplicationRecord
  RETENTION_PERIOD = 30.days
  self.table_name = 'openjarvis_api_requests'

  belongs_to :integration_hook, class_name: 'Integrations::Hook'

  encrypts :response_body if Chatwoot.encryption_configured?

  enum status: { processing: 0, completed: 1 }

  validates :idempotency_key, presence: true, length: { maximum: 128 }
  validates :operation, presence: true, length: { maximum: 100 }
  validates :request_digest, presence: true, length: { is: 64 }
  before_validation :set_expiration, on: :create

  scope :expired, -> { where(expires_at: ...Time.current) }

  def parsed_response_body
    JSON.parse(response_body.presence || '{}')
  end

  private

  def set_expiration
    self.expires_at ||= RETENTION_PERIOD.from_now
  end
end
