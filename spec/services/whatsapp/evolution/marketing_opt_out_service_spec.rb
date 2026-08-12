require 'rails_helper'

RSpec.describe Whatsapp::Evolution::MarketingOptOutService do
  let(:contact) { create(:contact) }
  let(:conversation) { create(:conversation, account: contact.account, contact: contact) }

  it 'records an exact SAIR reply as a WhatsApp marketing opt-out' do
    message = create(:message, conversation: conversation, account: contact.account,
                               sender: contact, message_type: :incoming, content: ' SAIR! ')

    expect(described_class.new(contact: contact, message: message).perform).to be(true)

    expect(contact.reload.additional_attributes['whatsapp_marketing_unsubscribed']).to be(true)
    expect(contact.additional_attributes['whatsapp_marketing_unsubscribed_at']).to be_present
  end

  it 'does not interpret normal support language as an opt-out' do
    message = create(:message, conversation: conversation, account: contact.account,
                               sender: contact, message_type: :incoming, content: 'Quero cancelar minha reserva')

    expect(described_class.new(contact: contact, message: message).perform).to be(false)
    expect(contact.reload.additional_attributes['whatsapp_marketing_unsubscribed']).to be_blank
  end
end
