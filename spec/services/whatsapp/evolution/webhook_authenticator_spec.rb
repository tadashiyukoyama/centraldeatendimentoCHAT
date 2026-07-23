require 'rails_helper'

RSpec.describe Whatsapp::Evolution::WebhookAuthenticator do
  let(:provisioning) { build(:whatsapp_evolution_provisioning, instance_name: 'cw-a1-test', webhook_secret: 'webhook-secret') }
  let(:payload) { { 'instance' => 'cw-a1-test', 'event' => 'connection.update' } }
  let(:claims) do
    {
      'app' => 'evolution',
      'action' => 'webhook',
      'iat' => Time.current.to_i,
      'exp' => 10.minutes.from_now.to_i
    }
  end

  it 'accepts a valid short-lived instance-bound token' do
    token = JWT.encode(claims, provisioning.webhook_secret, 'HS256')
    service = described_class.new(
      provisioning: provisioning,
      authorization_header: "Bearer #{token}",
      payload: payload
    )

    expect(service.verify!).to be(true)
  end

  it 'rejects a token for another instance' do
    token = JWT.encode(claims, provisioning.webhook_secret, 'HS256')
    service = described_class.new(
      provisioning: provisioning,
      authorization_header: "Bearer #{token}",
      payload: payload.merge('instance' => 'different-instance')
    )

    expect { service.verify! }.to raise_error(
      Whatsapp::Evolution::WebhookAuthenticator::AuthenticationError,
      'Webhook instance mismatch'
    )
  end

  it 'rejects an unexpected application claim' do
    token = JWT.encode(claims.merge('app' => 'unexpected'), provisioning.webhook_secret, 'HS256')
    service = described_class.new(
      provisioning: provisioning,
      authorization_header: "Bearer #{token}",
      payload: payload
    )

    expect { service.verify! }.to raise_error(
      Whatsapp::Evolution::WebhookAuthenticator::AuthenticationError,
      'Invalid webhook claims'
    )
  end
end
