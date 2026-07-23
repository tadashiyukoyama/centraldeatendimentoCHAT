FactoryBot.define do
  factory :whatsapp_evolution_provisioning, class: 'Whatsapp::EvolutionProvisioning' do
    account
    sequence(:public_id) { |n| "evolution-public-#{n}" }
    sequence(:instance_name) { |n| "cw-a1-test-#{n}" }
    sequence(:inbox_name) { |n| "Evolution WhatsApp #{n}" }
    instance_token { SecureRandom.hex(32) }
    webhook_secret { SecureRandom.hex(32) }
    status { :waiting_qr }
    expires_at { 15.minutes.from_now }
  end
end
