require 'rails_helper'

RSpec.describe Openjarvis::Configuration do
  let(:account) { create(:account) }
  let(:service_user) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:inbox, account: account) }
  let(:hook) { build(:integrations_hook, :openjarvis, account: account, service_user: service_user, allowed_inboxes: [inbox]) }

  it 'accepts an HTTPS endpoint and account-scoped resources' do
    expect(described_class.new(hook)).to be_valid
  end

  it 'rejects embedded credentials and old Chatwoot domains' do
    hook.settings['endpoint_url'] = 'https://user:pass@events.chatwoot.com./events?token=unsafe'

    expect(described_class.new(hook).errors).to include(
      'Webhook endpoint cannot contain embedded credentials',
      'Webhook endpoint cannot contain a query string',
      'Webhook endpoint cannot use an old Chatwoot domain'
    )
  end

  it 'rejects inboxes that do not belong to the account' do
    other_inbox = create(:inbox)
    hook.settings['allowed_inbox_ids'] = [other_inbox.id]

    expect(described_class.new(hook).errors).to include('One or more inboxes do not belong to this account')
  end

  it 'separates removed inbox ids from the recoverable allowlist' do
    removed_id = inbox.id
    inbox.destroy!
    configuration = described_class.new(hook)

    expect(configuration.stale_allowed_inbox_ids).to eq([removed_id])
    expect(configuration.existing_allowed_inbox_ids).to be_empty
  end

  it 'authorizes all current and future account inboxes only for an administrator' do
    hook.settings['inbox_access_mode'] = 'all_account'
    hook.settings['allowed_inbox_ids'] = []
    configuration = described_class.new(hook)

    expect(configuration).to be_valid
    expect(configuration).to be_all_account_inboxes
    expect(configuration.effective_inbox_count).to eq(1)

    agent = create(:user, account: account, role: :agent)
    hook.settings['service_user_id'] = agent.id
    expect(described_class.new(hook).errors).to include(
      'All current and future inbox access requires an administrator service user'
    )
  end

  it 'requires an endpoint only when webhooks are enabled' do
    hook.settings['endpoint_url'] = ''
    hook.settings['webhooks_enabled'] = false
    expect(described_class.new(hook)).to be_valid

    hook.settings['webhooks_enabled'] = true
    expect(described_class.new(hook).errors).to include('Webhook endpoint is required when webhooks are enabled')
  end
end
