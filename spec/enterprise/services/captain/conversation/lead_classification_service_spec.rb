require 'rails_helper'

RSpec.describe Captain::Conversation::LeadClassificationService, type: :service do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, status: :pending) }
  let(:service) { described_class.new(conversation: conversation) }

  def add_customer_message(content)
    create(
      :message,
      conversation: conversation,
      account: account,
      inbox: inbox,
      sender: contact,
      message_type: :incoming,
      content: content
    )
  end

  it 'persists a valid model classification and preserves unrelated labels' do
    create(:label, account: account, title: 'restaurante')
    conversation.update_labels(['restaurante'])
    add_customer_message('Gostaria de conhecer a solucao')

    expect(service.perform(classification: 'lead_morno')).to eq('lead_morno')
    expect(conversation.reload.label_list).to contain_exactly('restaurante', 'lead_morno')
  end

  it 'replaces an existing business classification' do
    add_customer_message('Quero contratar e saber o preco')
    service.perform(classification: 'lead_quente')

    expect(conversation.reload.label_list).to contain_exactly('lead_quente')
  end

  it 'falls back to a hot lead for an explicit buying signal' do
    add_customer_message('Quanto custa o plano profissional?')

    expect(service.perform).to eq('lead_quente')
    expect(conversation.reload.label_list).to include('lead_quente')
  end

  it 'falls back to cliente for an existing customer support request' do
    add_customer_message('Ja sou cliente e nao consigo fazer login')

    expect(service.perform).to eq('cliente')
    expect(conversation.reload.label_list).to include('cliente')
  end

  it 'falls back to a warm lead for a discovery message' do
    add_customer_message('Ola, gostaria de entender como funciona')

    expect(service.perform).to eq('lead_morno')
    expect(conversation.reload.label_list).to include('lead_morno')
  end

  it 'does not treat a product discovery question about reducing errors as an existing customer' do
    add_customer_message(
      'Quero entender como o AI Food Manager ajuda a reduzir erros nos pedidos. ' \
      'Meu e-mail e lead@example.com e minha empresa e Restaurante Exemplo.'
    )

    expect(service.perform(classification: 'cliente')).to eq('lead_morno')
    expect(conversation.reload.label_list).to include('lead_morno')
  end

  it 'does not treat a prospect asking about customer support as an existing customer' do
    add_customer_message('Gostaria de saber como funciona o suporte para os clientes')

    expect(service.perform(classification: 'cliente')).to eq('lead_morno')
  end

  it 'recognizes an existing customer who explicitly says they use the platform' do
    add_customer_message('Ja uso a plataforma e estou com dificuldade no acesso')

    expect(service.perform).to eq('cliente')
  end

  it 'falls back when the model returns an unsupported classification' do
    add_customer_message('Quero saber o valor do plano')

    expect(service.perform(classification: 'prospect')).to eq('lead_quente')
    expect(conversation.reload.label_list).to include('lead_quente')
  end

  it 'does not downgrade a hot lead when a later model result says warm' do
    add_customer_message('Quero marcar uma demonstracao')
    service.perform(classification: 'lead_quente')
    add_customer_message('Obrigado')

    expect(service.perform(classification: 'lead_morno')).to eq('lead_quente')
    expect(conversation.reload.label_list).to include('lead_quente')
  end

  it 'does not accept a hot model classification without a buying signal' do
    add_customer_message('Gostaria de entender como funciona')

    expect(service.perform(classification: 'lead_quente')).to eq('lead_morno')
  end

  it 'does not accept a customer model classification without a customer signal' do
    add_customer_message('Bom dia')

    expect(service.perform(classification: 'cliente')).to eq('lead_morno')
  end

  it 'recreates a canonical label if it was removed from the account' do
    add_customer_message('Quero marcar uma demonstracao')

    expect { service.perform(classification: 'lead_quente') }
      .to change { account.labels.where(title: 'lead_quente').count }.from(0).to(1)
  end
end
