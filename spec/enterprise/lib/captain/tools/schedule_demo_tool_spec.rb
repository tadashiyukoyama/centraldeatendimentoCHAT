require 'rails_helper'

RSpec.describe Captain::Tools::ScheduleDemoTool, type: :model do
  let(:account) { create(:account) }
  let!(:fallback_admin) { create(:user, account: account, role: :administrator) }
  let(:specialist) { create(:user, account: account, role: :administrator) }
  let(:assistant) do
    create(
      :captain_assistant,
      account: account,
      config: { 'demo_assignee_email' => specialist.email }
    )
  end
  let(:inbox) { create(:inbox, account: account, timezone: 'America/Sao_Paulo') }
  let(:contact) do
    create(
      :contact,
      account: account,
      name: 'Cesar',
      phone_number: '+5511999999999',
      additional_attributes: { 'company_name' => 'Mar Azul' }
    )
  end
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, status: :pending) }
  let(:tool) { described_class.new(assistant) }
  let(:tool_context) do
    Struct.new(:state).new({
                             conversation: { id: conversation.id },
                             contact: { id: contact.id }
                           })
  end
  let(:starts_at_time) do
    2.days.from_now.in_time_zone('America/Sao_Paulo').change(hour: 14, min: 0, sec: 0)
  end
  let(:starts_at) { starts_at_time.iso8601 }

  before do
    create(
      :message,
      account: account,
      inbox: inbox,
      conversation: conversation,
      sender: assistant,
      message_type: :outgoing,
      content: "Confirmo sua demonstração para #{starts_at_time.strftime('%d/%m/%Y')} às 14:00?"
    )
    create(
      :message,
      account: account,
      inbox: inbox,
      conversation: conversation,
      sender: contact,
      message_type: :incoming,
      content: 'Sim, confirmo'
    )
  end

  it 'creates the appointment, classifies the lead, and hands off to the specialist' do
    result = tool.perform(
      tool_context,
      starts_at: starts_at,
      duration_minutes: 30,
      timezone: 'America/Sao_Paulo'
    )

    expect(result).to start_with('Conversation handed off to owner')
    appointment = Captain::Appointment.last
    expect(appointment).to have_attributes(specialist_id: specialist.id, contact_id: contact.id, status: 'scheduled')
    expect(conversation.reload).to have_attributes(status: 'open', assignee_id: specialist.id)
    expect(conversation.label_list).to include('demo_agendada', 'lead_quente')
  end

  it 'rejects an unconfirmed slot even when the lead accepted a generic demo offer' do
    Message.where(conversation_id: conversation.id).delete_all
    create(
      :message,
      account: account,
      inbox: inbox,
      conversation: conversation,
      sender: assistant,
      message_type: :outgoing,
      content: 'Deseja conhecer os benefícios em uma demonstração?'
    )
    create(
      :message,
      account: account,
      inbox: inbox,
      conversation: conversation,
      sender: contact,
      message_type: :incoming,
      content: 'Sim, quero'
    )

    result = tool.perform(tool_context, starts_at: starts_at, timezone: 'America/Sao_Paulo')

    expect(result).to include('exact demonstration slot')
    expect(Captain::Appointment.count).to eq(0)
    expect(Captain::ToolExecution.last).to have_attributes(status: 'rejected', error_code: 'demo_slot_not_confirmed')
  end

  it 'rejects scheduling until the required contact fields are saved' do
    contact.update!(phone_number: nil)

    result = tool.perform(tool_context, starts_at: starts_at, timezone: 'America/Sao_Paulo')

    expect(result).to include('Collect and save')
    expect(Captain::Appointment.count).to eq(0)
  end

  it 'assigns the configured specialist instead of the fallback administrator' do
    tool.perform(tool_context, starts_at: starts_at, timezone: 'America/Sao_Paulo')

    expect(conversation.reload.assignee_id).to eq(specialist.id)
    expect(conversation.assignee_id).not_to eq(fallback_admin.id)
  end

  it 'rolls back the appointment when the handoff cannot be completed' do
    handoff_tool = instance_double(Captain::Tools::HandoffTool, perform_trusted: 'Failed to handoff conversation')
    allow(Captain::Tools::HandoffTool).to receive(:new).with(assistant).and_return(handoff_tool)

    result = tool.perform(tool_context, starts_at: starts_at, timezone: 'America/Sao_Paulo')

    expect(result).to eq('Failed to handoff conversation')
    expect(Captain::Appointment.count).to eq(0)
    expect(conversation.reload.status).to eq('pending')
    expect(conversation.label_list).not_to include('demo_agendada')
    expect(Captain::ToolExecution.last).to have_attributes(status: 'rejected', error_code: 'handoff_rejected')
  end

  it 'audits an invalid date as a rejected tool execution' do
    result = tool.perform(tool_context, starts_at: 'amanhã às 14h', timezone: 'America/Sao_Paulo')

    expect(result).to include('Invalid appointment date')
    expect(Captain::ToolExecution.last).to have_attributes(status: 'rejected', error_code: 'invalid_schedule')
  end
end
