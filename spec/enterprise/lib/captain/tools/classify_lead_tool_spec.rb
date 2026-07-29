require 'rails_helper'

RSpec.describe Captain::Tools::ClassifyLeadTool, type: :model do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:tool) { described_class.new(assistant) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:tool_context) { Struct.new(:state).new({ conversation: { id: conversation.id } }) }

  before do
    described_class::CLASSIFICATIONS.each { |title| create(:label, account: account, title: title) }
  end

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

  it 'elevates an existing lead only when the latest customer message has a buying signal' do
    create(:label, account: account, title: 'restaurante')
    conversation.update_labels(%w[lead_morno restaurante])
    add_customer_message('Quero marcar uma demonstracao')

    result = tool.perform(tool_context, classification: 'lead_quente')

    expect(result).to include("classified as 'lead_quente'")
    expect(conversation.reload.label_list).to contain_exactly('lead_quente', 'restaurante')
  end

  it 'does not let the model elevate a profile-only reply to a hot lead' do
    conversation.update_labels(['lead_morno'])
    add_customer_message('Meu nome e Cesar e meu WhatsApp e +5511999999999')

    result = tool.perform(tool_context, classification: 'lead_quente')

    expect(result).to include("classified as 'lead_morno'")
    expect(conversation.reload.label_list).to contain_exactly('lead_morno')
  end

  it 'rejects classifications outside the canonical set' do
    result = tool.perform(tool_context, classification: 'prospect')

    expect(result).to include('Invalid classification')
    expect(conversation.reload.label_list).to be_empty
  end
end
