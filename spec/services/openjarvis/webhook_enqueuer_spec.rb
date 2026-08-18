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
  end

  it 'does not queue resources from an inbox outside the connection' do
    conversation = create(:conversation, account: account, inbox: create(:inbox, account: account))

    expect do
      described_class.new(account: account, event_name: 'conversation.created', resource: conversation).perform
    end.not_to have_enqueued_job(Openjarvis::WebhookDeliveryJob)
  end

  it 'does not queue events while webhooks are disabled' do
    hook.update!(settings: hook.settings.merge('webhooks_enabled' => false))
    conversation = create(:conversation, account: account, inbox: inbox)

    expect do
      described_class.new(account: account, event_name: 'conversation.created', resource: conversation).perform
    end.not_to have_enqueued_job(Openjarvis::WebhookDeliveryJob)
  end
end
