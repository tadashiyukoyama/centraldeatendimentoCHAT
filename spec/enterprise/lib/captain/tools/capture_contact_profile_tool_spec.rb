require 'rails_helper'

RSpec.describe Captain::Tools::CaptureContactProfileTool, type: :model do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account, name: '') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:tool) { described_class.new(assistant) }
  let(:tool_context) do
    Struct.new(:state).new({
                             conversation: { id: conversation.id },
                             contact: { id: contact.id }
                           })
  end

  before do
    create(
      :message,
      account: account,
      inbox: inbox,
      conversation: conversation,
      sender: contact,
      message_type: :incoming,
      content: 'Meu nome é Cesar, meu restaurante é Mar Azul e meu telefone é (11) 99999-9999.'
    )
    conversation.update_labels(['lead_morno'])
  end

  it 'saves only details explicitly provided by the customer' do
    result = tool.perform(
      tool_context,
      name: 'Cesar',
      company_name: 'Mar Azul',
      phone_number: '(11) 99999-9999',
      country_code: 'BR'
    )

    expect(result).to include('Contact profile saved')
    expect(contact.reload).to have_attributes(name: 'Cesar', phone_number: '+5511999999999', contact_type: 'lead')
    expect(contact.additional_attributes['company_name']).to eq('Mar Azul')
    expect(Captain::ToolExecution.last).to have_attributes(status: 'succeeded')
  end

  it 'rejects a value that was inferred instead of provided' do
    result = tool.perform(tool_context, company_name: 'Empresa inventada')

    expect(result).to include('Do not save inferred data')
    expect(contact.reload.additional_attributes['company_name']).to be_blank
    expect(Captain::ToolExecution.last).to have_attributes(status: 'rejected', error_code: 'missing_customer_evidence')
  end

  it 'does not accept a local phone without a supported country code' do
    result = tool.perform(tool_context, phone_number: '11999999999', country_code: 'US')

    expect(result).to include('international country code')
    expect(contact.reload.phone_number).to be_blank
    expect(Captain::ToolExecution.last).to have_attributes(status: 'rejected', error_code: 'invalid_phone')
  end

  it 'uses the conversation contact even if the tool state contains another contact id' do
    other_contact = create(:contact, account: account, name: '')
    mismatched_context = Struct.new(:state).new({
                                                  conversation: { id: conversation.id },
                                                  contact: { id: other_contact.id }
                                                })

    tool.perform(mismatched_context, name: 'Cesar')

    expect(contact.reload.name).to eq('Cesar')
    expect(other_contact.reload.name).to be_blank
    expect(Captain::ToolExecution.last.contact_id).to eq(contact.id)
  end
end
