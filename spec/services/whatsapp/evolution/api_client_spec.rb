require 'rails_helper'

RSpec.describe Whatsapp::Evolution::ApiClient do
  let(:provisioning) do
    build(
      :whatsapp_evolution_provisioning,
      instance_name: 'cw-a1-test',
      instance_token: 'instance-key'
    )
  end
  let(:valid_env) do
    {
      EVOLUTION_API_ENABLED: 'true',
      EVOLUTION_API_URL: 'https://evolution.example.com',
      EVOLUTION_API_KEY: 'global-key',
      FRONTEND_URL: 'https://chat.example.com'
    }
  end

  before do
    allow(Chatwoot).to receive(:encryption_configured?).and_return(true)
  end

  it 'uses the global key only to create an instance and configures authenticated webhooks' do
    request = stub_request(:post, 'https://evolution.example.com/instance/create')
              .with(
                headers: { 'apikey' => 'global-key' },
                body: hash_including(
                  'instanceName' => 'cw-a1-test',
                  'token' => 'instance-key',
                  'integration' => 'WHATSAPP-BAILEYS',
                  'webhook' => hash_including(
                    'url' => "https://chat.example.com/webhooks/evolution/#{provisioning.public_id}",
                    'webhookBase64' => false,
                    'headers' => { 'jwt_key' => provisioning.webhook_secret }
                  )
                )
              )
              .to_return(
                status: 201,
                body: { qrcode: { base64: 'qr-data' } }.to_json,
                headers: { 'Content-Type' => 'application/json' }
              )

    with_modified_env valid_env do
      expect(described_class.new(provisioning: provisioning).create_instance.dig('qrcode', 'base64')).to eq('qr-data')
    end
    expect(request).to have_been_requested.once
  end

  it 'uses the per-instance key for messages and normalizes the destination number' do
    request = stub_request(:post, 'https://evolution.example.com/message/sendText/cw-a1-test')
              .with(
                headers: { 'apikey' => 'instance-key' },
                body: { number: '5511999999999', text: 'Hello' }
              )
              .to_return(
                status: 201,
                body: { key: { id: 'message-id' } }.to_json,
                headers: { 'Content-Type' => 'application/json' }
              )

    with_modified_env valid_env do
      result = described_class.new(provisioning: provisioning).send_text(number: '+55 11 99999-9999', text: 'Hello')
      expect(result.dig('key', 'id')).to eq('message-id')
    end
    expect(request).to have_been_requested.once
  end

  it 'does not include a remote error body in raised errors' do
    stub_request(:get, 'https://evolution.example.com/instance/connectionState/cw-a1-test')
      .to_return(status: 401, body: { apikey: 'leaked-key', message: 'sensitive remote response' }.to_json)

    with_modified_env valid_env do
      expect do
        described_class.new(provisioning: provisioning).connection_state
      end.to raise_error(Whatsapp::Evolution::ApiClient::Error, 'Evolution API request failed with HTTP 401')
    end
  end
end
