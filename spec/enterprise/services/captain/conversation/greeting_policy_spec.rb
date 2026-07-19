require 'rails_helper'

RSpec.describe Captain::Conversation::GreetingPolicy, type: :service do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }

  def add_customer_message(content)
    create(
      :message,
      conversation: conversation,
      account: account,
      inbox: inbox,
      sender: contact,
      message_type: :incoming,
      content: content
    )
  end

  it 'recognizes a first greeting without forcing qualification' do
    add_customer_message('Bom dia')

    expect(described_class.new(conversation).greeting_only?).to be true
  end

  it 'does not treat a later greeting as a fresh greeting-only episode after intent was shared' do
    add_customer_message('Tenho um restaurante e quero organizar as reservas')
    add_customer_message('Bom dia')

    expect(described_class.new(conversation).greeting_only?).to be false
  end
end
