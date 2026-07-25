require 'rails_helper'

RSpec.describe Webhooks::EvolutionEventsJob do
  it 'does not write webhook payload arguments to Active Job logs' do
    expect(described_class.log_arguments?).to be(false)
  end

  it 'discards an event removed during provisioning teardown' do
    expect do
      described_class.perform_now(-1, {})
    end.not_to raise_error
  end

  it 'serializes message webhooks for the same Evolution inbox and contact' do
    provisioning = create(:whatsapp_evolution_provisioning, status: :connected)
    channel = build(
      :channel_whatsapp,
      account: provisioning.account,
      provider: 'evolution',
      provider_config: { 'evolution_provisioning_id' => provisioning.id }
    )
    channel.evolution_provisioning_validation_id = provisioning.id
    channel.save!
    provisioning.update!(whatsapp_channel: channel)
    create(:inbox, account: provisioning.account, channel: channel)
    event = provisioning.events.create!(event_key: SecureRandom.hex, event_type: 'messages_upsert')
    payload = {
      event: 'messages.upsert',
      data: { key: { remoteJid: '5511999999999@s.whatsapp.net' } }
    }
    processor = instance_double(Whatsapp::Evolution::WebhookProcessor, perform: true)
    job = described_class.new
    mutex_key = format(
      Redis::Alfred::WHATSAPP_MESSAGE_MUTEX,
      inbox_id: "evolution-#{provisioning.id}",
      sender_id: '5511999999999@s.whatsapp.net'
    )

    allow(Whatsapp::Evolution::WebhookProcessor).to receive(:new)
      .with(event: event, payload: payload)
      .and_return(processor)
    expect(job).to receive(:with_lock).with(mutex_key, 30.seconds).and_yield

    job.perform(event.id, payload)
    expect(processor).to have_received(:perform)
  end

  it 'processes connection events without a contact mutex' do
    provisioning = create(:whatsapp_evolution_provisioning)
    event = provisioning.events.create!(event_key: SecureRandom.hex, event_type: 'connection_update')
    payload = { event: 'connection.update', data: { state: 'connecting' } }
    processor = instance_double(Whatsapp::Evolution::WebhookProcessor, perform: true)
    job = described_class.new

    allow(Whatsapp::Evolution::WebhookProcessor).to receive(:new).and_return(processor)
    expect(job).not_to receive(:with_lock)

    job.perform(event.id, payload)
    expect(processor).to have_received(:perform)
  end
end
