require 'rails_helper'

RSpec.describe Captain::Assistant::TurnResponsePresentationService do
  def present(response)
    described_class.new(response: response).perform
  end

  it 'adds a stage-relevant emoji without another model call' do
    response = {
      response: 'Qual dia e horário você prefere para a demonstração?',
      commercial_stage: 'scheduling',
      customer_intent: 'prospect'
    }

    expect(present(response)['response']).to eq('Qual dia e horário você prefere para a demonstração? 📅')
  end

  it 'preserves a response that already contains an emoji' do
    response = {
      response: 'Vamos entender sua operação. 😊',
      commercial_stage: 'discovery',
      customer_intent: 'prospect'
    }

    expect(present(response)['response']).to eq(response[:response])
  end

  it 'does not decorate customer support responses' do
    response = {
      response: 'Vou verificar seu atendimento.',
      commercial_stage: 'support',
      customer_intent: 'customer'
    }

    expect(present(response)['response']).to eq(response[:response])
  end
end
