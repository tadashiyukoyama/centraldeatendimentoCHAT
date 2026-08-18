FactoryBot.define do
  factory :openjarvis_api_request, class: 'Openjarvis::ApiRequest' do
    association :integration_hook, factory: [:integrations_hook, :openjarvis]
    sequence(:idempotency_key) { |number| "fixture-request-#{number}" }
    operation { 'contacts.create' }
    request_digest { Digest::SHA256.hexdigest('{}') }
    status { :completed }
    response_status { 200 }
    response_body { '{}' }
    completed_at { Time.current }
  end

  factory :openjarvis_webhook_delivery, class: 'Openjarvis::WebhookDelivery' do
    association :integration_hook, factory: [:integrations_hook, :openjarvis]
    delivery_id { SecureRandom.uuid }
    event_id { SecureRandom.uuid }
    event_name { 'contact.updated' }
    resource_type { 'Contact' }
    sequence(:resource_id)
    resource_version { "#{Time.current.utc.iso8601(6)}:1" }
    resource_sequence { 1 }
    payload_digest { Digest::SHA256.hexdigest('{}') }
  end
end
