require 'rails_helper'

RSpec.describe Openjarvis::WebhookEnqueuer do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:service_user) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:inbox, account: account) }
  let!(:hook) do
    create(:integrations_hook, :openjarvis, account: account, service_user: service_user, allowed_inboxes: [inbox])
  end

  it 'records and queues an authorized subscribed event' do
    conversation = create(:conversation, account: account, inbox: inbox)

    expect do
      described_class.new(account: account, event_name: 'conversation.created', resource: conversation).perform
    end.to have_enqueued_job(Openjarvis::WebhookDeliveryJob)
      .and change(Openjarvis::WebhookDelivery, :count).by(1)

    delivery = Openjarvis::WebhookDelivery.last
    expect(delivery).to have_attributes(
      event_id: be_present,
      schema_version: '1.0',
      resource_version: be_present,
      resource_sequence: 1
    )
  end

  it 'increments a monotonic sequence for duplicate or out-of-order delivery handling' do
    conversation = create(:conversation, account: account, inbox: inbox)

    2.times do
      described_class.new(account: account, event_name: 'conversation.updated', resource: conversation).perform
    end

    expect(hook.openjarvis_webhook_deliveries.order(:created_at).pluck(:resource_sequence)).to eq([1, 2])
  end

  it 'does not queue resources from an inbox outside the connection' do
    conversation = create(:conversation, account: account, inbox: create(:inbox, account: account))

    expect do
      described_class.new(account: account, event_name: 'conversation.created', resource: conversation).perform
    end.not_to have_enqueued_job(Openjarvis::WebhookDeliveryJob)
  end

  it 'queues events from an inbox created after all-account access was enabled' do
    hook.update!(
      settings: hook.settings.merge(
        'inbox_access_mode' => 'all_account',
        'allowed_inbox_ids' => []
      )
    )
    future_inbox = create(:inbox, account: account)
    conversation = create(:conversation, account: account, inbox: future_inbox)

    expect do
      described_class.new(account: account, event_name: 'conversation.created', resource: conversation).perform
    end.to have_enqueued_job(Openjarvis::WebhookDeliveryJob)
  end

  it 'does not queue events while webhooks are disabled' do
    hook.update!(settings: hook.settings.merge('webhooks_enabled' => false))
    conversation = create(:conversation, account: account, inbox: inbox)

    expect do
      described_class.new(account: account, event_name: 'conversation.created', resource: conversation).perform
    end.not_to have_enqueued_job(Openjarvis::WebhookDeliveryJob)
  end
end
