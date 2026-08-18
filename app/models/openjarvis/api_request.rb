class Openjarvis::ApiRequest < ApplicationRecord
  self.table_name = 'openjarvis_api_requests'

  belongs_to :integration_hook, class_name: 'Integrations::Hook'

  encrypts :response_body if Chatwoot.encryption_configured?

  enum status: { processing: 0, completed: 1 }

  validates :idempotency_key, presence: true, length: { maximum: 128 }
  validates :operation, presence: true, length: { maximum: 100 }
  validates :request_digest, presence: true, length: { is: 64 }
  def parsed_response_body
    JSON.parse(response_body.presence || '{}')
  end
end
