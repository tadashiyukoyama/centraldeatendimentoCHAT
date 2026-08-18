require 'rails_helper'

RSpec.describe Openjarvis::RetentionJob do
  it 'removes expired ledgers and expired credential overlap only' do
    hook = create(:integrations_hook, :openjarvis)
    expired_request = create(:openjarvis_api_request, integration_hook: hook, expires_at: 1.minute.ago)
    retained_request = create(:openjarvis_api_request, integration_hook: hook, expires_at: 1.day.from_now)
    expired_delivery = create(:openjarvis_webhook_delivery, integration_hook: hook, expires_at: 1.minute.ago)
    retained_delivery = create(:openjarvis_webhook_delivery, integration_hook: hook, expires_at: 1.day.from_now)
    hook.update!(
      previous_access_token: 'expired-token-value',
      previous_access_token_expires_at: 1.minute.ago,
      previous_webhook_secret: 'retained-secret-value',
      previous_webhook_secret_expires_at: 1.day.from_now
    )

    described_class.perform_now

    expect(Openjarvis::ApiRequest.exists?(expired_request.id)).to be(false)
    expect(Openjarvis::ApiRequest.exists?(retained_request.id)).to be(true)
    expect(Openjarvis::WebhookDelivery.exists?(expired_delivery.id)).to be(false)
    expect(Openjarvis::WebhookDelivery.exists?(retained_delivery.id)).to be(true)
    expect(hook.reload.previous_access_token).to be_nil
    expect(hook.previous_webhook_secret).to eq('retained-secret-value')
  end
end
