require 'rails_helper'

RSpec.describe Whatsapp::Evolution::Configuration do
  let(:valid_env) do
    {
      EVOLUTION_API_ENABLED: 'true',
      EVOLUTION_API_URL: 'https://evolution.example.com',
      EVOLUTION_API_KEY: 'global-key',
      FRONTEND_URL: 'https://chat.example.com',
      EVOLUTION_API_BASIC_AUTH_USER: nil,
      EVOLUTION_API_BASIC_AUTH_PASSWORD: nil
    }
  end

  before do
    allow(Chatwoot).to receive(:encryption_configured?).and_return(true)
  end

  it 'accepts a complete HTTPS configuration' do
    with_modified_env valid_env do
      expect(described_class.validate!).to be(true)
      expect(described_class.webhook_url('public-id')).to eq('https://chat.example.com/webhooks/evolution/public-id')
    end
  end

  it 'fails closed when the integration is disabled' do
    with_modified_env valid_env.merge(EVOLUTION_API_ENABLED: 'false') do
      expect { described_class.validate! }.to raise_error(
        Whatsapp::Evolution::Configuration::ConfigurationError,
        'Evolution API integration is disabled'
      )
    end
  end

  it 'fails closed when encryption is unavailable' do
    allow(Chatwoot).to receive(:encryption_configured?).and_return(false)

    with_modified_env valid_env do
      expect { described_class.validate! }.to raise_error(
        Whatsapp::Evolution::Configuration::ConfigurationError,
        'Evolution API requires Active Record encryption'
      )
    end
  end

  it 'requires both Basic Authentication values when either is configured' do
    with_modified_env valid_env.merge(EVOLUTION_API_BASIC_AUTH_USER: 'proxy-user') do
      expect { described_class.validate! }.to raise_error(
        Whatsapp::Evolution::Configuration::ConfigurationError,
        'Evolution API Basic Authentication requires both user and password'
      )
    end
  end
end
