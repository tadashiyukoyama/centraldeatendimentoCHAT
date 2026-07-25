require 'rails_helper'

RSpec.describe Internal::CheckNewVersionsJob do
  subject(:job) { described_class.perform_now }

  let(:reconsile_premium_config_service) { instance_double(Internal::ReconcilePlanConfigService) }

  before do
    allow(Internal::ReconcilePlanConfigService).to receive(:new).and_return(reconsile_premium_config_service)
    allow(reconsile_premium_config_service).to receive(:perform)
    allow(Rails.env).to receive(:production?).and_return(true)
  end

  it 'updates the plan info' do
    data = { 'version' => '1.2.3', 'plan' => 'enterprise', 'plan_quantity' => 1, 'chatwoot_support_website_token' => '123',
             'chatwoot_support_identifier_hash' => '123', 'chatwoot_support_script_url' => '123' }
    allow(ChatwootHub).to receive(:sync_with_hub).and_return(data)
    job
    expect(InstallationConfig.find_by(name: 'INSTALLATION_PRICING_PLAN').value).to eq 'enterprise'
    expect(InstallationConfig.find_by(name: 'INSTALLATION_PRICING_PLAN_QUANTITY').value).to eq 1
    expect(InstallationConfig.find_by(name: 'CHATWOOT_SUPPORT_WEBSITE_TOKEN').value).to eq '123'
    expect(InstallationConfig.find_by(name: 'CHATWOOT_SUPPORT_IDENTIFIER_HASH').value).to eq '123'
    expect(InstallationConfig.find_by(name: 'CHATWOOT_SUPPORT_SCRIPT_URL').value).to eq '123'
  end

  it 'calls Internal::ReconcilePlanConfigService' do
    data = { 'version' => '1.2.3' }
    allow(ChatwootHub).to receive(:sync_with_hub).and_return(data)
    job
    expect(reconsile_premium_config_service).to have_received(:perform)
  end

  it 'does not clear persisted values when the response is empty' do
    existing_plan = create(:installation_config, name: 'INSTALLATION_PRICING_PLAN', value: 'enterprise')
    existing_quantity = create(:installation_config, name: 'INSTALLATION_PRICING_PLAN_QUANTITY', value: 10)
    allow(ChatwootHub).to receive(:sync_with_hub).and_return({})

    job

    expect(existing_plan.reload.value).to eq('enterprise')
    expect(existing_quantity.reload.value).to eq(10)
  end

  it 'ignores an unsupported plan' do
    existing_plan = create(:installation_config, name: 'INSTALLATION_PRICING_PLAN', value: 'enterprise')
    allow(ChatwootHub).to receive(:sync_with_hub).and_return('plan' => 'untrusted')

    job

    expect(existing_plan.reload.value).to eq('enterprise')
  end
end
