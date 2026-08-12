require 'rails_helper'

RSpec.describe Captain::Assistant::TurnContractValidator do
  let(:base_policy) do
    {
      required_profile_fields_if_prospect: %w[name company_name],
      machine_detected_profile_fields: [],
      initial_classification_labels: ['lead_morno'],
      likely_profile_reply: false,
      latest_message_has_profile_refusal: false,
      declinable_profile_fields: []
    }
  end
  let(:base_response) do
    {
      response: "Posso te orientar com uma **visão prática**. 👋\n\nComo posso te chamar e qual é o seu estabelecimento?",
      reasoning: 'Advance discovery and identify the lead.',
      classification: 'lead_morno',
      customer_intent: 'prospect',
      commercial_stage: 'qualification',
      immediate_objective: 'Capture lead identity',
      captured_profile_fields: [],
      requested_profile_fields: %w[name company_name],
      declined_profile_fields: [],
      knowledge_grounded: false
    }
  end
  let(:context) { { state: { cw_metadata: {} }, captain_v2_tool_results: [] } }
  let(:run_result) { instance_double(Agents::RunResult, context: context) }

  def validator(response: base_response, policy: base_policy, recent_responses: [])
    described_class.new(response: response, run_result: run_result, policy: policy, recent_responses: recent_responses)
  end

  it 'accepts an adaptive profile request authored by the agent' do
    expect(validator.errors).to eq([])
  end

  it 'does not confuse the restaurant name with the contact person name' do
    response = base_response.merge(
      response: 'Para eu entender seu cenário, qual é o **nome do restaurante** e a cidade onde ele fica? 👋'
    )

    expect(validator(response: response).errors).to include(
      'requested profile fields are missing from the customer-facing question: name'
    )
  end

  it 'accepts distinct person and establishment wording in one natural question' do
    response = base_response.merge(
      response: 'Para eu te orientar, qual é o **nome da pessoa responsável** e o nome do restaurante? 👋'
    )

    expect(validator(response: response).errors).to eq([])
  end

  it 'requires both contact fields to be present in the question paragraph' do
    policy = base_policy.merge(required_profile_fields_if_prospect: %w[phone_number email])
    response = base_response.merge(
      response: 'Para continuar, qual é o seu **WhatsApp**? 👋',
      requested_profile_fields: %w[phone_number email]
    )

    expect(validator(response: response, policy: policy).errors).to include(
      'requested profile fields are missing from the customer-facing question: email'
    )
  end

  it 'rejects a prospect turn that silently skips due profile coverage' do
    response = base_response.merge(requested_profile_fields: [], response: 'Vamos entender sua operação. 👋')

    expect(validator(response: response).errors.join).to include('name, company_name')
  end

  it 'requires explicit email and phone data to be persisted by the profile tool' do
    policy = base_policy.merge(
      required_profile_fields_if_prospect: [],
      machine_detected_profile_fields: %w[email phone_number]
    )
    response = base_response.merge(requested_profile_fields: [], captured_profile_fields: %w[email phone_number])

    expect(validator(response: response, policy: policy).errors.join).to include('capture_contact_profile')
  end

  it 'does not allow a lead classification to evade the profile contract with unknown intent' do
    response = base_response.merge(customer_intent: 'unknown')

    expect(validator(response: response).errors).to include(
      'customer_intent must be prospect for classification lead_morno'
    )
  end

  it 'requires a likely profile reply to use the real persistence tool' do
    policy = base_policy.merge(
      required_profile_fields_if_prospect: [],
      previous_requested_profile_fields: %w[name company_name],
      likely_profile_reply: true
    )
    response = base_response.merge(requested_profile_fields: [], captured_profile_fields: [])

    expect(validator(response: response, policy: policy).errors).to include(
      'likely profile reply requires capture_contact_profile or an explicit refusal'
    )
  end

  it 'does not accept declined fields without refusal evidence' do
    policy = base_policy.merge(required_profile_fields_if_prospect: [])
    response = base_response.merge(requested_profile_fields: [], declined_profile_fields: ['email'])

    expect(validator(response: response, policy: policy).errors).to include(
      'declined profile fields require an explicit refusal in the latest customer message'
    )
  end

  it 'accepts only fields actually covered by explicit refusal evidence' do
    policy = base_policy.merge(
      required_profile_fields_if_prospect: [],
      latest_message_has_profile_refusal: true,
      declinable_profile_fields: ['phone_number']
    )
    response = base_response.merge(
      requested_profile_fields: [],
      declined_profile_fields: %w[phone_number email]
    )

    expect(validator(response: response, policy: policy).errors).to include(
      'declined profile fields are not supported by the latest refusal: email'
    )
  end

  it 'accepts captured fields only when the real tool confirms persistence' do
    context[:captain_v2_tool_results] = [
      {
        name: 'captain--tools--capture_contact_profile',
        result: { status: 'saved', saved_fields: %w[email phone_number] }.to_json
      }
    ]
    policy = base_policy.merge(
      required_profile_fields_if_prospect: [],
      machine_detected_profile_fields: %w[email phone_number]
    )
    response = base_response.merge(requested_profile_fields: [], captured_profile_fields: %w[email phone_number])

    expect(validator(response: response, policy: policy).errors).to eq([])
  end

  it 'requires FAQ evidence for factual product claims' do
    response = base_response.merge(
      response: "**Atendimento centralizado:** a plataforma reúne seus canais em uma única visão. 🚀\n\nQual canal mais gera retrabalho hoje?",
      requested_profile_fields: [],
      declined_profile_fields: [],
      knowledge_grounded: true
    )

    expect(validator(response: response).errors.join).to include('FAQ lookup')
  end

  it 'accepts grounded claims when FAQ lookup returned approved sources' do
    context[:captain_v2_tool_results] = [{ name: 'captain--tools--faq_lookup', result: 'Approved answer' }]
    context[:state][:cw_metadata] = { faq_ids: [45] }
    response = base_response.merge(
      response: "**Atendimento centralizado:** a plataforma reúne seus canais em uma única visão. 🚀\n\nQual canal mais gera retrabalho hoje?",
      requested_profile_fields: [],
      declined_profile_fields: [],
      knowledge_grounded: true
    )

    policy = base_policy.merge(required_profile_fields_if_prospect: [])

    expect(validator(response: response, policy: policy).errors).to eq([])
  end

  it 'rejects unstructured, emoji-free substantive commercial copy' do
    response = base_response.merge(
      response: 'A plataforma pode ajudar sua equipe a organizar o atendimento em vários canais com mais contexto e menos perda de informação.',
      requested_profile_fields: [],
      declined_profile_fields: %w[name company_name]
    )

    expect(validator(response: response).errors).to include(
      'commercial response must use one relevant emoji',
      'substantive commercial response must use selective Markdown bold'
    )
  end

  it 'rejects repetition of a recent complete sentence' do
    repeated = 'Vamos entender sua operação para mostrar o que realmente faz sentido no seu cenário.'
    response = base_response.merge(response: "#{repeated} 👋\n\nComo posso te chamar e qual é o seu estabelecimento?")

    expect(validator(response: response, recent_responses: [repeated]).errors).to include('response repeats a recent complete sentence')
  end
end
