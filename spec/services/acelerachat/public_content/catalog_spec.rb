require 'rails_helper'

RSpec.describe Acelerachat::PublicContent::Catalog do
  let(:facts) do
    {
      LEGAL_ENTITY_NAME: 'Acelera Serviços Ltda.',
      LEGAL_ENTITY_CNPJ: '00.000.000/0001-00',
      LEGAL_ENTITY_ADDRESS: 'Rua Exemplo, 100, São Paulo/SP',
      LEGAL_DPO_NAME: 'Encarregado Exemplo',
      PRIVACY_CONTACT_EMAIL: 'privacidade@meugerenciador.pro',
      SUPPORT_CONTACT_EMAIL: 'suporte@aifoodmanager.pro',
      ACELERACHAT_PUBLIC_CONTENT_AUTHOR_EMAIL: 'author@example.com'
    }
  end

  it 'loads and interpolates the 76 versioned documents' do
    with_modified_env facts do
      catalog = described_class.new.validate!

      expect(catalog.documents.size).to eq(76)
      expect(catalog.documents.count { |document| document.kind == 'help' && document.locale == 'pt_BR' }).to eq(22)
      expect(catalog.documents.count { |document| document.kind == 'legal' && document.locale == 'en' }).to eq(16)
      expect(catalog.find_legal_route!('terms', 'pt_BR').content).to include('Acelera Serviços Ltda.')
      expect(catalog.documents.map(&:content).join).not_to match(/\{\{[A-Z_]+\}\}/)
    end
  end

  it 'allows an absent CNPJ without publishing an empty registration label' do
    with_modified_env facts.merge(LEGAL_ENTITY_CNPJ: '') do
      catalog = described_class.new.validate!
      terms = catalog.find_legal_route!('terms', 'pt_BR').content

      expect(terms).to include('Acelera Serviços Ltda.')
      expect(terms).not_to include('CNPJ')
      expect(terms).not_to include('{{LEGAL_ENTITY_CNPJ}}')
    end
  end

  it 'rejects malformed operator identifiers and contact addresses' do
    with_modified_env facts.merge(LEGAL_ENTITY_CNPJ: 'invalid', PRIVACY_CONTACT_EMAIL: 'not-an-email') do
      expect { described_class.new.validate! }.to raise_error(ArgumentError, /LEGAL_ENTITY_CNPJ/)
    end
  end

  it 'rejects legacy first-party domains in factual contact addresses' do
    with_modified_env facts.merge(PRIVACY_CONTACT_EMAIL: 'privacy@chatwoot.com') do
      expect { described_class.new.validate! }.to raise_error(ArgumentError, /legacy first-party domain/)
    end
  end
end
