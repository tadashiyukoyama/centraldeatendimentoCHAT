require 'rails_helper'

RSpec.describe Openjarvis::ContactInboxResolver do
  it 'derives a WhatsApp association from the contact phone without a client source_id' do
    channel = create(:channel_whatsapp, validate_provider_config: false, sync_templates: false)
    contact = create(:contact, account: channel.account, phone_number: '+5511999990000')

    result = described_class.new(contact: contact, inbox: channel.inbox).resolve!

    expect(result).to have_attributes(contact_id: contact.id, inbox_id: channel.inbox.id, source_id: '5511999990000')
  end

  it 'requires a real provider association for Instagram' do
    channel = create(:channel_instagram)
    contact = create(:contact, account: channel.account)

    expect do
      described_class.new(contact: contact, inbox: channel.inbox).resolve!
    end.to raise_error(Openjarvis::ApiError) { |error| expect(error.code).to eq('contact_inbox_missing') }
  end
end
