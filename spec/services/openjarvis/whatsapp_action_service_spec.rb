require 'rails_helper'

RSpec.describe Openjarvis::WhatsappActionService do
  let(:account) { create(:account) }
  let(:channel) do
    create(
      :channel_whatsapp,
      account: account,
      provider: 'evolution',
      validate_provider_config: false,
      sync_templates: false
    )
  end
  let(:inbox) { channel.inbox }
  let(:contact_inbox) { create(:contact_inbox, inbox: inbox, source_id: '5511999999999') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact_inbox: contact_inbox) }
  let(:provider_service) { instance_double(Whatsapp::Providers::EvolutionService) }

  before do
    create(
      :whatsapp_evolution_provisioning,
      account: account,
      whatsapp_channel: channel,
      status: :connected
    )
    allow(channel).to receive(:provider_service).and_return(provider_service)
  end

  it 'reacts to a provider-backed message' do
    message = create(:message, :incoming, conversation: conversation, account: account, source_id: 'provider-message-id')
    allow(provider_service).to receive(:send_reaction).and_return({})

    result = described_class.new(conversation: conversation).react(message: message, reaction: '👍')

    expect(provider_service).to have_received(:send_reaction).with(
      phone_number: '5511999999999',
      message: message,
      reaction: '👍'
    )
    expect(result).to include(result_state: 'applied', provider: 'evolution')
  end

  it 'sends provider read receipts and updates the internal read marker' do
    conversation.update!(agent_last_seen_at: nil)
    first = create(:message, :incoming, conversation: conversation, account: account, source_id: 'provider-1', created_at: 2.minutes.ago)
    second = create(:message, :incoming, conversation: conversation, account: account, source_id: 'provider-2', created_at: 1.minute.ago)
    allow(provider_service).to receive(:mark_messages_read).and_return({})

    result = described_class.new(conversation: conversation).mark_read

    expect(provider_service).to have_received(:mark_messages_read).with(
      phone_number: '5511999999999',
      messages: [second, first]
    )
    expect(result).to include(provider_receipt_sent: true, message_count: 2)
    expect(conversation.reload.agent_last_seen_at).to be_within(1.second).of(second.created_at)
  end

  it 'does not call the provider when the Evolution inbox is disconnected' do
    channel.evolution_provisioning.update!(status: :disconnected)
    message = create(:message, :incoming, conversation: conversation, account: account, source_id: 'provider-message-id')
    allow(provider_service).to receive(:send_reaction)

    expect do
      described_class.new(conversation: conversation).react(message: message, reaction: '👍')
    end.to raise_error(Openjarvis::ApiError) { |error| expect(error.code).to eq('source_disconnected') }
    expect(provider_service).not_to have_received(:send_reaction)
  end
end
