require 'rails_helper'

RSpec.describe AceleraControl do
  let(:signing_key) { OpenSSL::PKey::RSA.new(2048) }
  let(:instance_id) { 'instance-123' }
  let(:control_env) do
    {
      'ACELERA_CONTROL_ENABLED' => 'true',
      'ACELERA_CONTROL_URL' => 'https://control.acelerachat.example',
      'ACELERA_CONTROL_TOKEN' => 'test-control-token',
      'ACELERA_CONTROL_PUBLIC_KEY' => signing_key.public_key.to_pem
    }
  end
  let(:entitlement) do
    {
      'instance_id' => instance_id,
      'plan_code' => 'pro',
      'seat_limit' => 25,
      'status' => 'active',
      'expires_at' => 1.day.from_now.iso8601,
      'grace_until' => 2.days.from_now.iso8601,
      'features' => %w[audit_logs nemmo],
      'latest_release' => { 'version' => '5.0.0', 'sha' => 'a' * 40 },
      'support' => {
        'base_url' => 'https://suporte.acelerachat.example',
        'website_token' => 'support-token',
        'identifier_hash' => 'support-hash'
      }
    }
  end

  before do
    allow(Rails.logger).to receive(:warn)
  end

  describe '.heartbeat' do
    it 'does not perform a request when the control plane is disabled' do
      allow(RestClient::Request).to receive(:execute)

      expect(described_class.heartbeat(instance_id: instance_id)).to eq({})
      expect(RestClient::Request).not_to have_received(:execute)
    end

    it 'accepts a signed entitlement and maps PRO to the existing internal plan' do
      response = instance_double(RestClient::Response, to_s: signed_envelope(entitlement))
      allow(RestClient::Request).to receive(:execute).and_return(response)

      result = with_modified_env(control_env) do
        described_class.heartbeat(instance_id: instance_id, app_version: '4.15.1', source_sha: 'b' * 40)
      end

      expect(result).to include(
        'plan' => 'enterprise',
        'plan_quantity' => 25,
        'version' => '5.0.0',
        'acelera_release_sha' => 'a' * 40,
        'acelera_entitlements' => %w[audit_logs nemmo],
        'chatwoot_support_script_url' => 'https://suporte.acelerachat.example'
      )
      expect(RestClient::Request).to have_received(:execute).with(
        hash_including(
          method: :post,
          url: 'https://control.acelerachat.example/v1/instances/heartbeat',
          open_timeout: 3,
          read_timeout: 5,
          headers: hash_including(authorization: 'Bearer test-control-token')
        )
      )
    end

    it 'rejects an entitlement with an invalid signature and preserves local state' do
      other_key = OpenSSL::PKey::RSA.new(2048)
      response = instance_double(RestClient::Response, to_s: signed_envelope(entitlement, key: other_key))
      allow(RestClient::Request).to receive(:execute).and_return(response)

      result = with_modified_env(control_env) do
        described_class.heartbeat(instance_id: instance_id)
      end

      expect(result).to eq({})
      expect(Rails.logger).to have_received(:warn).with(/response ignored/)
    end

    it 'rejects an entitlement issued for another instance' do
      response = instance_double(
        RestClient::Response,
        to_s: signed_envelope(entitlement.merge('instance_id' => 'another-instance'))
      )
      allow(RestClient::Request).to receive(:execute).and_return(response)

      result = with_modified_env(control_env) do
        described_class.heartbeat(instance_id: instance_id)
      end

      expect(result).to eq({})
    end

    it 'returns an empty response when the control plane is unavailable' do
      allow(RestClient::Request).to receive(:execute).and_raise(RestClient::Exceptions::OpenTimeout)

      result = with_modified_env(control_env) do
        described_class.heartbeat(instance_id: instance_id)
      end

      expect(result).to eq({})
    end
  end

  describe '.safe_external_url' do
    it 'accepts an AceleraChat HTTPS endpoint' do
      expect(described_class.safe_external_url('https://control.acelerachat.example/path')).to eq(
        'https://control.acelerachat.example/path'
      )
    end

    it 'rejects HTTP and every legacy Chatwoot domain' do
      expect(described_class.safe_external_url('http://control.acelerachat.example')).to be_nil
      expect(described_class.safe_external_url('https://hub.2.chatwoot.com')).to be_nil
      expect(described_class.safe_external_url('https://docs.chatwoot.help')).to be_nil
      expect(described_class.safe_external_url('https://chwt.app/example')).to be_nil
    end
  end

  def signed_envelope(payload, key: signing_key)
    raw_payload = payload.to_json
    signature = key.sign(OpenSSL::Digest.new('SHA256'), raw_payload)
    {
      payload: Base64.strict_encode64(raw_payload),
      signature: Base64.strict_encode64(signature)
    }.to_json
  end
end
