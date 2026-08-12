# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Captain::PromptRenderer do
  let(:context) do
    {
      feature_commercial_response_contract: true,
      feature_contact_profile: true,
      conversation: { id: 137 },
      commercial_turn: {
        enabled: true,
        required_profile_fields_if_prospect: %w[name company_name],
        missing_profile_fields: %w[name company_name phone_number email],
        previous_requested_profile_fields: [],
        declined_profile_fields: [],
        likely_profile_reply: false,
        latest_message_has_profile_refusal: false,
        declinable_profile_fields: [],
        machine_detected_profile_fields: [],
        initial_classification_labels: []
      },
      commercial_validation_feedback: [
        'profile fields due in this turn were neither captured nor requested: name, company_name'
      ],
      commercial_retry: {
        tools_locked: true,
        previous_response: { response: 'Qual parte da operacao mais precisa de ajuda?' },
        completed_tool_results: []
      },
      response_guidelines: [],
      guardrails: [],
      tools: []
    }
  end

  it 'reserves the one customer-facing question for every due field' do
    rendered = described_class.render('assistant', context)

    expect(rendered).to include('hard profile-coverage obligation')
    expect(rendered).to include('request all named fields together')
    expect(rendered).to include('name, company_name')
    expect(rendered).to include('request both together')
    expect(rendered).to include('remove factual product claims')
  end

  it 'applies the same correction rule to scenario agents' do
    rendered = described_class.render('scenario', context)

    expect(rendered).to include('request every due profile field together')
    expect(rendered).to include('corrected response must request every named field together')
    expect(rendered).to include('request both together')
    expect(rendered).to include('remove factual product claims')
  end
end
