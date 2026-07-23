require 'rails_helper'

RSpec.describe Whatsapp::Evolution::WebhookProcessor do
  let(:provisioning) { create(:whatsapp_evolution_provisioning) }

  it 'maps Evolution delivery acknowledgements to the Chatwoot message status' do
    message = create(:message, source_id: 'evolution-message-id', status: :sent)
    event = provisioning.events.create!(
      event_key: SecureRandom.hex,
      event_type: 'messages_update'
    )
    payload = {
      event: 'messages.update',
      instance: provisioning.instance_name,
      data: {
        keyId: message.source_id,
        status: 'DELIVERY_ACK'
      }
    }

    described_class.new(event: event, payload: payload).perform

    expect(event.reload).to be_processed
    expect(message.reload).to be_delivered
  end

  it 'ignores unknown statuses without changing the message' do
    message = create(:message, source_id: 'evolution-message-id', status: :sent)
    event = provisioning.events.create!(
      event_key: SecureRandom.hex,
      event_type: 'messages_update'
    )
    payload = {
      event: 'messages.update',
      instance: provisioning.instance_name,
      data: {
        keyId: message.source_id,
        status: 'UNKNOWN'
      }
    }

    described_class.new(event: event, payload: payload).perform

    expect(event.reload).to be_ignored
    expect(message.reload).to be_sent
  end

  it 'fetches the connected identity when the connection webhook omits wuid' do
    event = provisioning.events.create!(
      event_key: SecureRandom.hex,
      event_type: 'connection_update'
    )
    payload = {
      event: 'connection.update',
      instance: provisioning.instance_name,
      data: { state: 'open' }
    }
    client = instance_double(Whatsapp::Evolution::ApiClient)
    finalizer = instance_double(Whatsapp::Evolution::FinalizeProvisioningService, perform: true)

    allow(Whatsapp::Evolution::ApiClient).to receive(:new).with(provisioning: provisioning).and_return(client)
    allow(client).to receive(:fetch_instance).and_return(
      'ownerJid' => '5511999999999@s.whatsapp.net',
      'profileName' => 'Support'
    )
    allow(Whatsapp::Evolution::FinalizeProvisioningService).to receive(:new).and_return(finalizer)

    described_class.new(event: event, payload: payload).perform

    expect(event.reload).to be_processed
    expect(client).to have_received(:fetch_instance)
  end

  it 'synchronizes the connection before handling an early message event' do
    event = provisioning.events.create!(
      event_key: SecureRandom.hex,
      event_type: 'messages_upsert'
    )
    payload = {
      event: 'messages.upsert',
      instance: provisioning.instance_name,
      data: {
        key: {
          remoteJid: '5511999999999@s.whatsapp.net',
          fromMe: false,
          id: 'early-message'
        },
        message: { conversation: 'Hello' }
      }
    }
    sync = instance_double(Whatsapp::Evolution::ConnectionSyncService, perform: true)

    allow(Whatsapp::Evolution::ConnectionSyncService).to receive(:new)
      .with(provisioning: provisioning)
      .and_return(sync)

    described_class.new(event: event, payload: payload).perform

    expect(sync).to have_received(:perform)
    expect(event.reload).to be_ignored
  end
end
