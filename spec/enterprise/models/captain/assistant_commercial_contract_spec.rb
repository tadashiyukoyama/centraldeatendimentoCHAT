require 'rails_helper'
require 'yaml'

RSpec.describe Captain::Assistant do
  describe 'AI Food Manager commercial contract' do
    let(:source) do
      YAML.safe_load_file(
        Rails.root.join('config/captain/assistants/aifood_manager.yml'),
        permitted_classes: [],
        aliases: false
      )
    end
    let(:guidelines) { source.fetch('response_guidelines').join(' ') }
    let(:assistant_prompt) do
      Rails.root.join('enterprise/lib/captain/prompts/assistant.liquid').read
    end

    it 'versions the consultative flow and assigns public wording to one authority' do
      expect(source.fetch('version')).to eq(9)
      expect(assistant_prompt).to include('only authority for customer-facing wording')
      expect(assistant_prompt).to include('Runtime code will validate and deliver it exactly')
    end

    it 'requires need discovery, non-repetition, and clarification before profile collection' do
      expect(guidelines).to include('consultor comercial, não como formulário')
      expect(guidelines).to include('não repita lista de benefícios')
      expect(guidelines).to include('pergunta de diagnóstico')
      expect(guidelines).to include('peça esclarecimento')
      expect(guidelines).to include('A ausência de um campo nunca obriga uma pergunta')
      expect(guidelines).to include('sem entrevista campo a campo')
    end

    it 'uses the inbox timezone by default instead of interrogating the lead about it' do
      expect(guidelines).to include('Use o fuso configurado da caixa como padrão')
      expect(assistant_prompt).to include('Treat it as the default for dates and times')
      expect(assistant_prompt).to include('Do not ask the customer for a timezone')
    end

    it 'uses a structured pending slot before scheduling a confirmed demonstration' do
      expect(guidelines).to include('registrar o horário pendente')
      expect(guidelines).to include('confirmation_required')
      expect(assistant_prompt).to include('register the exact pending slot')
      expect(assistant_prompt).to include('exactly the same start, duration, and timezone')
    end

    it 'keeps quality safeguards in the global Agent SDK prompt' do
      expect(assistant_prompt).to include('Every response must add new value')
      expect(assistant_prompt).to include('Never repeat the same benefit list')
      expect(assistant_prompt).to include('ask what the customer meant')
      expect(assistant_prompt).to include('Ask at most one conversational question per reply')
    end
  end
end
