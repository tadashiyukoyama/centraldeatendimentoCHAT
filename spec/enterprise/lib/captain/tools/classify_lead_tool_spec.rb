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

  it 'replaces an existing lead classification' do
    conversation.update_labels(%w[lead_morno restaurante])

    result = tool.perform(tool_context, classification: 'lead_quente')

    expect(result).to include("classified as 'lead_quente'")
    expect(conversation.reload.label_list).to contain_exactly('lead_quente', 'restaurante')
  end

  it 'rejects classifications outside the canonical set' do
    result = tool.perform(tool_context, classification: 'prospect')

    expect(result).to include('Invalid classification')
    expect(conversation.reload.label_list).to be_empty
  end
end
