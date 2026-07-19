require 'rails_helper'

RSpec.describe Captain::Conversation::OriginResolver, type: :service do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, :with_email, account: account) }
  let(:website_inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:service) { described_class.new(conversation) }

  it 'persists spontaneous origin for a direct channel conversation' do
    expect(service.perform).to eq('spontaneous')
    expect(conversation.reload.additional_attributes['captain_origin']).to eq('spontaneous')
  end

  it 'detects a website widget conversation as link origin' do
    website_conversation = create(:conversation, account: account, inbox: website_inbox, contact: contact)

    expect(described_class.new(website_conversation).perform).to eq('link')
    expect(website_conversation.reload.additional_attributes['captain_origin']).to eq('link')
  end

  it 'detects a conversation linked to a campaign as campaign origin' do
    campaign = create(:campaign, account: account)
    conversation.update!(campaign: campaign)

    expect(service.perform).to eq('campaign')
    expect(conversation.reload.additional_attributes['captain_origin']).to eq('campaign')
  end

  it 'does not overwrite a previously persisted origin' do
    conversation.update!(additional_attributes: { 'captain_origin' => 'campaign' })

    expect(service.perform).to eq('campaign')
    expect(conversation.reload.additional_attributes['captain_origin']).to eq('campaign')
  end
end
