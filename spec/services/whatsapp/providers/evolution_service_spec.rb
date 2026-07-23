require 'rails_helper'

RSpec.describe Whatsapp::Providers::EvolutionService do
  let(:account) { create(:account) }
  let(:provisioning) do
    create(
      :whatsapp_evolution_provisioning,
      account: account,
      status: :connected,
      connected_number: '+5511888888888'
    )
  end
  let(:channel) do
    channel = Channel::Whatsapp.new(
      account: account,
      phone_number: provisioning.connected_number,
      provider: 'evolution',
      provider_config: { 'evolution_provisioning_id' => provisioning.id }
    )
    channel.evolution_provisioning_validation_id = provisioning.id
    channel.save!
    channel
  end
  let(:inbox) { create(:inbox, account: account, channel: channel) }
  let(:contact_inbox) { create(:contact_inbox, inbox: inbox, source_id: '5511999999999') }
  let(:conversation) { create(:conversation, inbox: inbox, contact_inbox: contact_inbox) }
  let(:client) { instance_double(Whatsapp::Evolution::ApiClient) }

  before do
    provisioning.update!(whatsapp_channel: channel)
    allow(Whatsapp::Evolution::ApiClient).to receive(:new).with(provisioning: provisioning).and_return(client)
  end

  it 'declares that Meta templates and the Meta session window do not apply' do
    service = described_class.new(whatsapp_channel: channel)

    expect(service.supports_templates?).to be(false)
    expect(service.session_window_enforced?).to be(false)
  end

  it 'rejects a channel that tries to reuse an existing provisioning' do
    channel
    duplicate = Channel::Whatsapp.new(
      account: account,
      phone_number: '+5511777777777',
      provider: 'evolution',
      provider_config: { 'evolution_provisioning_id' => provisioning.id }
    )

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:provider_config]).to include('Invalid Credentials')
  end

  it 'sends a regular message even when the Meta reply window is closed' do
    message = create(
      :message,
      message_type: :outgoing,
      content: 'Hello from support',
      conversation: conversation,
      account: account
    )
    allow(client).to receive(:send_text)
      .with(number: contact_inbox.source_id, text: 'Hello from support')
      .and_return('key' => { 'id' => 'evolution-message-id' })

    Whatsapp::SendOnWhatsappService.new(message: message).perform

    expect(message.reload.source_id).to eq('evolution-message-id')
  end

  it 'fails explicit Meta template attempts without calling Evolution' do
    message = create(
      :message,
      message_type: :outgoing,
      content: 'Template content',
      conversation: conversation,
      account: account,
      additional_attributes: { template_params: { name: 'meta-template' } }
    )
    allow(client).to receive(:send_text)

    Whatsapp::SendOnWhatsappService.new(message: message).perform

    expect(message.reload).to be_failed
    expect(message.external_error).to eq('Templates are not supported by this WhatsApp provider')
    expect(client).not_to have_received(:send_text)
  end
end
