require 'rails_helper'

RSpec.describe Acelerachat::PublicContent::SyncService do
  let!(:account) { create(:account, id: 1) }
  let!(:author) { create(:user, email: 'author@example.com') }
  let!(:account_user) { create(:account_user, account: account, user: author, role: :administrator) }
  let(:facts) do
    {
      LEGAL_ENTITY_NAME: 'Acelera Serviços Ltda.',
      LEGAL_ENTITY_CNPJ: '00.000.000/0001-00',
      LEGAL_ENTITY_ADDRESS: 'Rua Exemplo, 100, São Paulo/SP',
      LEGAL_DPO_NAME: 'Encarregado Exemplo',
      PRIVACY_CONTACT_EMAIL: 'privacidade@meugerenciador.pro',
      SUPPORT_CONTACT_EMAIL: 'suporte@aifoodmanager.pro',
      ACELERACHAT_PUBLIC_CONTENT_AUTHOR_EMAIL: author.email
    }
  end

  it 'checks the complete plan without mutating the database' do
    with_modified_env facts do
      expect { described_class.new(mode: :check).call }.not_to change(Portal, :count)
      expect(Article.count).to be_zero
    end
  end

  it 'rejects an author who belongs to account 1 without administrator privileges' do
    account_user.update!(role: :agent)

    with_modified_env facts do
      expect { described_class.new(mode: :check).call }.to raise_error(ArgumentError, /must be an administrator/)
    end
  end

  it 'creates the managed portal and remains idempotent' do
    with_modified_env facts do
      first = described_class.new(mode: :sync).call
      second = described_class.new(mode: :sync).call

      portal = Portal.find_by!(slug: 'acelerachat')
      expect(first.document_count).to eq(76)
      expect(portal.default_locale).to eq('pt_BR')
      expect(portal.layout).to eq('documentation')
      expect(portal.articles.published.count).to eq(76)
      expect(portal.articles.pluck(:meta).all? { |meta| meta['managed_by'] == 'acelerachat_public_content' }).to be(true)
      expect(second.actions.count { |action| action[:action] == 'unchanged' && action[:type] == 'article' }).to eq(76)
    end
  end

  it 'aborts on a manual article collision' do
    other_portal = create(:portal, account: account)
    create(:article, portal: other_portal, account: account, author: author, slug: 'campanhas')

    with_modified_env facts do
      expect { described_class.new(mode: :sync).call }.to raise_error(ArgumentError, /manual content/)
      expect(Portal.where(slug: 'acelerachat')).not_to exist
    end
  end

  it 'rolls back portal creation when article synchronization fails' do
    service = described_class.new(mode: :sync)
    allow(service).to receive(:sync_article!).and_raise(ActiveRecord::RecordInvalid)

    with_modified_env facts do
      expect { service.call }.to raise_error(ActiveRecord::RecordInvalid)
      expect(Portal.where(slug: 'acelerachat')).not_to exist
      expect(Article.count).to be_zero
    end
  end
end
