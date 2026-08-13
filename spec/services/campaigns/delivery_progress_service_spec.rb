require 'rails_helper'

RSpec.describe Campaigns::DeliveryProgressService do
  subject(:progress) { described_class.new(campaign: campaign).payload[:progress] }

  let(:account) { create(:account) }
  let(:sender) { create(:user, account: account, role: :administrator) }
  let(:channel) do
    create(:channel_whatsapp, account: account, provider: 'evolution',
                              validate_provider_config: false, sync_templates: false)
  end
  let(:label) { create(:label, account: account) }
  let(:campaign) do
    create(
      :campaign,
      account: account,
      inbox: channel.inbox,
      sender: sender,
      title: 'Scheduled prospects',
      message: 'Olá, {{contact.name}}!',
      scheduled_at: 1.hour.from_now,
      audience: [{ type: 'Label', id: label.id }],
      trigger_rules: {
        delivery_interval_min_minutes: 4,
        delivery_interval_max_minutes: 45,
        lawful_basis_confirmed: true
      }
    )
  end
  let!(:contacts) { create_list(:contact, 2, :with_phone_number, account: account) }

  before do
    contacts.each { |contact| contact.update_labels([label.title]) }
  end

  it 'reports the selected audience without creating deliveries before the scheduled processing' do
    expect(progress).to include(
      phase: 'scheduled',
      planned_total: 2,
      total: 0,
      completed: 0,
      percentage: 0
    )
    expect(campaign.campaign_deliveries).to be_empty
  end

  it 'distinguishes queue preparation from a processed empty audience' do
    campaign.processing!

    expect(progress).to include(phase: 'preparing', planned_total: 2, total: 0)
  end

  it 'uses the delivery snapshot as the source of truth after processing starts' do
    create(:campaign_delivery, campaign: campaign, contact: contacts.first, status: :pending)

    expect(progress).to include(phase: 'in_progress', planned_total: 2, total: 1)
    expect(progress).to include('pending' => 1)
  end

  it 'reports a genuinely empty completed campaign without changing the selected audience' do
    campaign.completed!

    expect(progress).to include(phase: 'empty', planned_total: 2, total: 0)
    expect(campaign.campaign_deliveries).to be_empty
  end
end
