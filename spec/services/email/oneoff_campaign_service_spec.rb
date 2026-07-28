require 'rails_helper'

RSpec.describe Email::OneoffCampaignService do
  subject(:service) { described_class.new(campaign: campaign) }

  let(:account) { create(:account) }
  let(:sender) { create(:user, account: account, role: :administrator) }
  let(:channel) { create(:channel_email, account: account) }
  let(:inbox) { channel.inbox }
  let(:label) { create(:label, account: account) }
  let(:campaign) do
    create(
      :campaign,
      account: account,
      inbox: inbox,
      sender: sender,
      audience: [{ type: 'Label', id: label.id }],
      template_params: {
        subject: 'Hello {{contact.name}}',
        lawful_basis_confirmed: true
      }
    )
  end

  before do
    campaign.processing!
  end

  it 'creates one idempotent delivery per eligible labelled contact' do
    eligible = create(:contact, account: account, email: 'eligible@example.com')
    blocked = create(:contact, account: account, email: 'blocked@example.com', blocked: true)
    no_email = create(:contact, account: account)
    unlabelled = create(:contact, account: account, email: 'unlabelled@example.com')
    [eligible, blocked, no_email].each { |contact| contact.update_labels([label.title]) }

    expect { service.perform }
      .to change(CampaignDelivery, :count).by(1)
      .and have_enqueued_job(Email::CampaignDeliveryJob).once

    expect(campaign.campaign_deliveries.first.contact).to eq(eligible)
    expect(campaign.reload).to be_processing

    expect { service.perform }.not_to change(CampaignDelivery, :count)
    expect(unlabelled.reload).to be_present
  end

  it 'completes a campaign with no eligible recipients' do
    service.perform

    expect(campaign.reload).to be_completed
  end
end
