require 'rails_helper'

RSpec.describe Captain::Conversation::LeadIntakeService do
  let(:account) { create(:account, locale: 'pt_BR') }
  let(:assistant) do
    create(
      :captain_assistant,
      account: account,
      config: { 'feature_contact_attributes' => true }
    )
  end
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) do
    create(
      :contact,
      account: account,
      name: 'patient-fire-116',
      additional_attributes: { 'captain_name_source' => 'generated' }
    )
  end
  let(:conversation) do
    create(:conversation, account: account, inbox: inbox, contact: contact, status: :pending).tap do |record|
      record.update_labels(['lead_morno'])
    end
  end

  def ask_and_answer(expected_field, answer)
    service = described_class.new(conversation: conversation, assistant: assistant)
    step = service.next_step
    expect(step.field).to eq(expected_field)

    service.mark_question_asked!(step, create_prompt(step))
    create_answer(answer)
  end

  def create_prompt(step)
    create(
      :message,
      account: account,
      inbox: inbox,
      conversation: conversation,
      sender: assistant,
      message_type: :outgoing,
      content: step.response
    )
  end

  def create_answer(answer)
    create(
      :message,
      account: account,
      inbox: inbox,
      conversation: conversation,
      sender: contact,
      message_type: :incoming,
      content: answer
    )
  end

  it 'collects the complete lead profile deterministically in the required order' do
    ask_and_answer(:name, 'Cesar Yukoyama')
    ask_and_answer(:company_name, 'Yukoyama Engine')
    ask_and_answer(:phone_number, '+55 (11) 99999-9999')
    ask_and_answer(:email, 'bellartecomercial@gmail.com')

    expect(described_class.new(conversation: conversation, assistant: assistant).next_step).to be_nil
    expect(contact.reload).to have_attributes(
      name: 'Cesar Yukoyama',
      phone_number: '+5511999999999',
      email: 'bellartecomercial@gmail.com',
      contact_type: 'lead'
    )
    expect(contact.additional_attributes).to include(
      'company_name' => 'Yukoyama Engine',
      'captain_name_source' => 'customer',
      'whatsapp_contact_permission' => true
    )
    expect(contact.additional_attributes.dig('whatsapp_contact_permission_details', 'scope')).to eq('service_follow_up')
    expect(contact.additional_attributes.dig('whatsapp_contact_permission_details', 'basis')).to eq(
      'number_voluntarily_provided_for_service_follow_up'
    )
  end

  it 'does not activate for an existing customer' do
    conversation.update_labels(['cliente'])

    expect(described_class.new(conversation: conversation, assistant: assistant).next_step).to be_nil
  end

  it 'repeats the same field when the answer is not valid' do
    ask_and_answer(:name, 'prefiro não informar')

    step = described_class.new(conversation: conversation, assistant: assistant).next_step

    expect(step.field).to eq(:name)
    expect(step.response).to include('Não consegui identificar seu nome')
    expect(contact.reload.name).to eq('patient-fire-116')
  end

  it 'does not repeat a question while it is waiting for the customer answer' do
    service = described_class.new(conversation: conversation, assistant: assistant)
    step = service.next_step
    prompt = create(
      :message,
      account: account,
      inbox: inbox,
      conversation: conversation,
      sender: assistant,
      message_type: :outgoing,
      content: step.response
    )
    service.mark_question_asked!(step, prompt)

    waiting_service = described_class.new(conversation: conversation, assistant: assistant)

    expect(waiting_service.next_step).to be_nil
    expect(waiting_service.awaiting_answer).to be(true)
  end
end
