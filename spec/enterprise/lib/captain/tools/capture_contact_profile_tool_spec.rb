require 'rails_helper'

RSpec.describe Captain::Tools::CaptureContactProfileTool, type: :model do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account, name: '') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:tool) { described_class.new(assistant) }
  let!(:profile_message) do
    create(
      :message,
      account: account,
      inbox: inbox,
      conversation: conversation,
      sender: contact,
      message_type: :incoming,
      content: 'Meu nome é Cesar, meu restaurante é Mar Azul, meu telefone é (11) 99999-9999 e meu email é cesar@example.com.'
    )
  end
  let(:tool_context) do
    Struct.new(:state).new({
                             conversation: { id: conversation.id },
                             contact: { id: contact.id }
                           })
  end

  before do
    conversation.update_labels(['lead_morno'])
  end

  it 'saves only details explicitly provided by the customer' do
    result = tool.perform(
      tool_context,
      name: 'Cesar',
      company_name: 'Mar Azul',
      phone_number: '(11) 99999-9999',
      email: 'cesar@example.com',
      country_code: 'BR'
    )

    payload = JSON.parse(result)
    expect(payload).to eq(
      'status' => 'saved',
      'profile_complete' => true,
      'missing_fields' => [],
      'saved_fields' => %w[name phone_number company_name email]
    )
    expect(contact.reload).to have_attributes(
      name: 'Cesar',
      phone_number: '+5511999999999',
      email: 'cesar@example.com',
      contact_type: 'lead'
    )
    expect(contact.additional_attributes['company_name']).to eq('Mar Azul')
    expect(contact.additional_attributes['whatsapp_contact_permission']).to be(true)
    permission_details = contact.additional_attributes['whatsapp_contact_permission_details']
    expect(permission_details).to include(
      'scope' => 'service_follow_up',
      'basis' => 'number_voluntarily_provided_for_service_follow_up',
      'conversation_id' => conversation.id,
      'inbox_id' => inbox.id,
      'message_id' => profile_message.id
    )
    expect(permission_details).not_to have_key('marketing_consent')
    expect(Captain::ToolExecution.last).to have_attributes(status: 'succeeded')
  end

  it 'captures an explicit field in any order and reports what is still missing' do
    payload = JSON.parse(tool.perform(tool_context, email: 'cesar@example.com'))

    expect(payload).to include(
      'status' => 'saved',
      'saved_fields' => ['email'],
      'profile_complete' => false
    )
    expect(payload['missing_fields']).to match_array(%w[name company_name phone_number])
    expect(contact.reload.email).to eq('cesar@example.com')
    expect(tool_context.state[:contact]).to include(email: 'cesar@example.com')
    expect(tool_context.state.dig(:contact_profile, :missing_fields)).to match_array(%w[name company_name phone_number])
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
