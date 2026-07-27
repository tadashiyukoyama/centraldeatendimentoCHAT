require 'rails_helper'

RSpec.describe Instagram::CommentAutomation::TemplateRenderer do
  subject(:renderer) do
    described_class.new(
      'Olá, {{username}}! Você comentou {{keyword}}.',
      allowed_variables: %w[username keyword]
    )
  end

  it 'renders only the supplied allowlisted variables' do
    expect(renderer.render(username: 'César', keyword: 'demo')).to eq('Olá, César! Você comentou demo.')
  end

  it 'truncates rendered output to the provider limit' do
    output = renderer.render({ username: 'cliente', keyword: 'demonstracao' }, max_length: 20)

    expect(output.length).to be <= 20
    expect(output).to end_with('…')
  end

  it 'rejects unknown variables' do
    invalid = described_class.new('Olá {{secret}}', allowed_variables: ['username'])

    expect { invalid.render(username: 'cliente') }
      .to raise_error(described_class::InvalidTemplate, /Unsupported template variables/)
  end

  it 'rejects Liquid control tags' do
    invalid = described_class.new('{% assign secret = "x" %}{{username}}', allowed_variables: ['username'])

    expect { invalid.render(username: 'cliente') }
      .to raise_error(described_class::InvalidTemplate, /control tags/)
  end
end
