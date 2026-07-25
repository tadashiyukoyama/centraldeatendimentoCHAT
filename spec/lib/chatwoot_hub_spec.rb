require 'rails_helper'

describe ChatwootHub do
  describe '.base_url' do
    it 'has no external destination by default' do
      expect(described_class.base_url).to be_nil
      expect(described_class.ping_url).to be_nil
    end
  end

  it 'generates installation identifier' do
    installation_identifier = described_class.installation_identifier
    expect(installation_identifier).not_to be_nil
    expect(described_class.installation_identifier).to eq installation_identifier
  end

  context 'when syncing control state' do
    it 'delegates a minimal payload to Acelera Control' do
      allow(AceleraControl).to receive(:heartbeat).and_return('version' => '5.0.0')

      expect(described_class.sync_with_hub['version']).to eq '5.0.0'
      expect(AceleraControl).to have_received(:heartbeat).with(
        hash_including(:instance_id, :app_version, :source_sha, :deployment_env, :edition)
      )
    end

    it 'does not include usage unless explicitly enabled' do
      allow(AceleraControl).to receive(:heartbeat).and_return({})

      described_class.sync_with_hub

      expect(AceleraControl).to have_received(:heartbeat) do |payload|
        expect(payload).not_to have_key(:active_users_count)
      end
    end

    it 'includes only seat usage when explicitly enabled' do
      allow(AceleraControl).to receive(:heartbeat).and_return({})
      allow(User).to receive(:count).and_return(4)

      with_modified_env ACELERA_CONTROL_INCLUDE_USAGE: 'true', DISABLE_TELEMETRY: 'false' do
        described_class.sync_with_hub
      end

      expect(AceleraControl).to have_received(:heartbeat).with(hash_including(active_users_count: 4))
    end
  end

  it 'does not register people, emit events or relay push notifications' do
    allow(RestClient::Request).to receive(:execute)

    expect(described_class.register_instance('Company', 'Owner', 'owner@example.com')).to be(false)
    expect(described_class.emit_event('event', sample: true)).to be(false)
    expect(described_class.send_push(payload: true)).to be(false)
    expect(described_class.push_relay_available?).to be(false)
    expect(RestClient::Request).not_to have_received(:execute)
  end

  describe '.support_config' do
    it 'rejects a legacy support endpoint even if it remains persisted locally' do
      create(:installation_config, name: 'CHATWOOT_SUPPORT_SCRIPT_URL', value: 'https://app.chatwoot.com')
      create(:installation_config, name: 'CHATWOOT_SUPPORT_WEBSITE_TOKEN', value: 'token')
      create(:installation_config, name: 'CHATWOOT_SUPPORT_IDENTIFIER_HASH', value: 'hash')

      expect(described_class.support_config).to eq(
        support_website_token: nil,
        support_script_url: nil,
        support_identifier_hash: nil
      )
    end
  end

  describe '.pricing_plan' do
    before do
      allow(ChatwootApp).to receive(:enterprise?).and_return(true)
      create(:installation_config, name: 'INSTALLATION_PRICING_PLAN', value: 'enterprise')
      create(:installation_config, name: 'INSTALLATION_PRICING_PLAN_QUANTITY', value: 25)
    end

    it 'keeps the local plan when Acelera Control is not managing the instance' do
      expect(described_class.pricing_plan).to eq('enterprise')
      expect(described_class.pricing_plan_quantity).to eq(25)
    end

    it 'keeps the managed plan during the signed grace period' do
      create(:installation_config, name: 'ACELERA_CONTROL_STATUS', value: 'active')
      create(:installation_config, name: 'ACELERA_CONTROL_GRACE_UNTIL', value: 1.day.from_now.iso8601)

      with_modified_env ACELERA_CONTROL_ENABLED: 'true' do
        expect(described_class.pricing_plan).to eq('enterprise')
        expect(described_class.pricing_plan_quantity).to eq(25)
      end
    end

    it 'fails closed after the managed grace period' do
      create(:installation_config, name: 'ACELERA_CONTROL_STATUS', value: 'active')
      create(:installation_config, name: 'ACELERA_CONTROL_GRACE_UNTIL', value: 1.minute.ago.iso8601)

      with_modified_env ACELERA_CONTROL_ENABLED: 'true' do
        expect(described_class.pricing_plan).to eq('community')
        expect(described_class.pricing_plan_quantity).to eq(0)
      end
    end

    it 'fails closed immediately for a suspended entitlement' do
      create(:installation_config, name: 'ACELERA_CONTROL_STATUS', value: 'suspended')
      create(:installation_config, name: 'ACELERA_CONTROL_GRACE_UNTIL', value: 1.day.from_now.iso8601)

      with_modified_env ACELERA_CONTROL_ENABLED: 'true' do
        expect(described_class.pricing_plan).to eq('community')
        expect(described_class.pricing_plan_quantity).to eq(0)
      end
    end
  end
end
