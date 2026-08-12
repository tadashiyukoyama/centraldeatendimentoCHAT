require 'rails_helper'

RSpec.describe Captain::Conversation::CommercialTurnPolicy do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) do
    create(
      :contact,
      account: account,
      name: 'quiet-river-123',
      additional_attributes: { 'captain_name_source' => 'generated' }
    )
  end
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }

  def incoming(content)
    create(:message, account: account, inbox: inbox, conversation: conversation, sender: contact, content: content, message_type: :incoming)
  end

  it 'does not require profile collection for an isolated greeting' do
    incoming('Olá')

    policy = described_class.new(conversation: conversation).perform

    expect(policy[:greeting_only]).to be true
    expect(policy[:required_profile_fields_if_prospect]).to eq([])
  end

  it 'requires identity coverage early without defining customer-facing wording' do
    incoming('Estou conhecendo a solução')

    policy = described_class.new(conversation: conversation).perform

    expect(policy[:required_profile_fields_if_prospect]).to contain_exactly('name', 'company_name')
    expect(policy).not_to have_key(:response_template)
  end

  it 'moves to WhatsApp and email on the next customer turn after identity is known' do
    contact.update!(
      name: 'Rodrigo Silva',
      phone_number: nil,
      email: nil,
      additional_attributes: { 'company_name' => 'Docs Restaurante', 'captain_name_source' => 'customer' }
    )
    incoming('Estou conhecendo')
    incoming('Quero melhorar o atendimento')

    policy = described_class.new(conversation: conversation).perform

    expect(policy[:required_profile_fields_if_prospect]).to contain_exactly('phone_number', 'email')
  end

  it 'recognizes a natural sentence that answers the previous identity request' do
    assistant = create(:captain_assistant, account: account)
    incoming('Estou conhecendo a solução')
    create(
      :captain_agent_session,
      account: account,
      assistant: assistant,
      subject: conversation,
      run_context: [
        {
          role: 'assistant',
          content: {
            commercial_stage: 'qualification',
            requested_profile_fields: %w[name company_name],
            declined_profile_fields: []
          }
        }
      ]
    )
    incoming('Tenho interesse em uma demonstração. Meu nome é Marina Teste Smoke e o restaurante é Sabor QA.')

    policy = described_class.new(conversation: conversation).perform

    expect(policy[:likely_profile_reply]).to be true
  end

  it 'does not repeat the same profile request in the immediately following turn' do
    assistant = create(:captain_assistant, account: account)
    incoming('Estou conhecendo')
    create(
      :captain_agent_session,
      account: account,
      assistant: assistant,
      subject: conversation,
      run_context: [
        {
          role: 'assistant',
          content: {
            commercial_stage: 'qualification',
            requested_profile_fields: %w[name company_name],
            declined_profile_fields: []
          }
        }
      ]
    )
    incoming('Mas primeiro quero entender os canais')

    policy = described_class.new(conversation: conversation).perform

    expect(policy[:previous_requested_profile_fields]).to contain_exactly('name', 'company_name')
    expect(policy[:required_profile_fields_if_prospect]).to eq([])
  end

  it 'marks a short answer to the previous profile request for real capture' do
    assistant = create(:captain_assistant, account: account)
    incoming('Estou conhecendo')
    create(
      :captain_agent_session,
      account: account,
      assistant: assistant,
      subject: conversation,
      run_context: [
        {
          role: 'assistant',
          content: {
            commercial_stage: 'qualification',
            requested_profile_fields: %w[name company_name],
            declined_profile_fields: []
          }
        }
      ]
    )
    incoming('Rodrigo, do Docs Restaurante')

    policy = described_class.new(conversation: conversation).perform

    expect(policy[:likely_profile_reply]).to be true
  end

  it 'detects an explicit refusal as a valid profile-request resolution' do
    assistant = create(:captain_assistant, account: account)
    incoming('Estou conhecendo')
    create(
      :captain_agent_session,
      account: account,
      assistant: assistant,
      subject: conversation,
      run_context: [
        {
          role: 'assistant',
          content: {
            commercial_stage: 'qualification',
            requested_profile_fields: ['phone_number'],
            declined_profile_fields: []
          }
        }
      ]
    )
    incoming('Prefiro não compartilhar')

    policy = described_class.new(conversation: conversation).perform

    expect(policy[:latest_message_has_profile_refusal]).to be true
    expect(policy[:likely_profile_reply]).to be true
    expect(policy[:declinable_profile_fields]).to eq(['phone_number'])
  end

  it 'detects explicit email and phone fields that require real tool execution' do
    incoming('Meu e-mail é lead@example.com e meu telefone é +5511999999999')

    policy = described_class.new(conversation: conversation).perform

    expect(policy[:machine_detected_profile_fields]).to contain_exactly('email', 'phone_number')
  end

  it 'ignores sessions that do not contain a commercial assistant contract' do
    assistant = create(:captain_assistant, account: account)
    incoming('Estou conhecendo a solução')
    create(
      :captain_agent_session,
      account: account,
      assistant: assistant,
      subject: conversation,
      run_context: [{ role: 'user', content: 'contexto sem saída estruturada' }]
    )

    policy = described_class.new(conversation: conversation).perform

    expect(policy[:previous_requested_profile_fields]).to eq([])
    expect(policy[:declined_profile_fields]).to eq([])
  end
end
