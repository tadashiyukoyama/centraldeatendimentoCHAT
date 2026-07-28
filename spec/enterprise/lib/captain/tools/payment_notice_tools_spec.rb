require 'rails_helper'

RSpec.describe 'Captain payment notice tools', type: :model do
  let(:account) { create(:account) }
  let!(:finance_team) { create(:team, account: account, name: 'financeiro') }
  let(:assistant) do
    create(:captain_assistant, account: account, config: { 'finance_team_id' => finance_team.id })
  end
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account, name: 'Cliente') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, status: :pending) }
  let(:tool_context) do
    Struct.new(:state).new({
                             conversation: { id: conversation.id },
                             contact: { id: contact.id }
                           })
  end

  before do
    create(
      :message,
      account: account,
      inbox: inbox,
      conversation: conversation,
      sender: contact,
      message_type: :incoming,
      content: 'Paguei R$ 150,00 da fatura FAT-123 via Pix e estou enviando o comprovante.'
    )
  end

  it 'records the notice as pending and routes the conversation to finance' do
    result = Captain::Tools::RecordPaymentNoticeTool.new(assistant).perform(
      tool_context,
      amount: '150,00',
      currency: 'BRL',
      reference: 'FAT-123'
    )

    expect(result).to start_with('Conversation handed off to financeiro')
    notice = Captain::PaymentNotice.last
    expect(notice).to have_attributes(status: 'pending_verification', amount_cents: 15_000, reference: 'FAT-123')
    expect(conversation.reload.team.name).to eq('financeiro')
    expect(conversation.label_list).to include('pagamento_informado')
  end

  it 'routes to the explicitly configured finance team' do
    configured_team = create(:team, account: account, name: 'cobranca')
    assistant.update!(config: { 'finance_team_id' => configured_team.id })

    result = Captain::Tools::RecordPaymentNoticeTool.new(assistant).perform(
      tool_context,
      amount: '150,00',
      currency: 'BRL',
      reference: 'FAT-123'
    )

    expect(result).to start_with('Conversation handed off to financeiro')
    expect(conversation.reload).to have_attributes(team_id: configured_team.id, assignee_id: nil)
  end

  it 'rejects the operation when no finance team is configured' do
    assistant.update!(config: {})

    result = Captain::Tools::RecordPaymentNoticeTool.new(assistant).perform(
      tool_context,
      amount: '150,00',
      currency: 'BRL',
      reference: 'FAT-123'
    )

    expect(result).to include('No finance team is configured')
    expect(Captain::PaymentNotice.count).to eq(0)
    expect(Captain::ToolExecution.last).to have_attributes(
      status: 'rejected',
      error_code: 'finance_team_not_configured'
    )
  end

  it 'rejects financial details not explicitly written by the customer' do
    result = Captain::Tools::RecordPaymentNoticeTool.new(assistant).perform(
      tool_context,
      amount: '999,00',
      currency: 'BRL',
      reference: 'INVENTADA-9'
    )

    expect(result).to include('amount was not found')
    expect(Captain::PaymentNotice.count).to eq(0)
    expect(Captain::ToolExecution.last).to have_attributes(
      status: 'rejected',
      error_code: 'payment_amount_not_explicit'
    )
  end

  it 'rejects an invented payment reference after validating an explicit amount' do
    result = Captain::Tools::RecordPaymentNoticeTool.new(assistant).perform(
      tool_context,
      amount: '150.00',
      currency: 'BRL',
      reference: 'INVENTADA-9'
    )

    expect(result).to include('reference was not found')
    expect(Captain::PaymentNotice.count).to eq(0)
    expect(Captain::ToolExecution.last).to have_attributes(
      status: 'rejected',
      error_code: 'payment_reference_not_explicit'
    )
  end

  it 'does not treat a general payment question as a payment notice' do
    Message.where(conversation_id: conversation.id).delete_all
    create(
      :message,
      account: account,
      inbox: inbox,
      conversation: conversation,
      sender: contact,
      message_type: :incoming,
      content: 'Como faço o pagamento da mensalidade?'
    )

    result = Captain::Tools::RecordPaymentNoticeTool.new(assistant).perform(tool_context)

    expect(result).to include('No explicit payment notice')
    expect(Captain::PaymentNotice.count).to eq(0)
    expect(Captain::ToolExecution.last).to have_attributes(
      status: 'rejected',
      error_code: 'payment_notice_not_explicit'
    )
  end

  it 'reports an internal pending status without claiming bank confirmation' do
    notice = create(
      :captain_payment_notice,
      account: account,
      assistant: assistant,
      conversation: conversation,
      contact: contact,
      status: :pending_verification,
      reference: 'FAT-123'
    )

    result = Captain::Tools::LookupPaymentStatusTool.new(assistant).perform(
      tool_context,
      reference: notice.reference
    )

    expect(result).to include('pending_verification')
    expect(result).to include('not a bank confirmation')
  end
end
