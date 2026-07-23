require 'rails_helper'

RSpec.describe Whatsapp::Evolution::EventKey do
  let(:provisioning) { create(:whatsapp_evolution_provisioning) }

  it 'distinguishes repeated connection states emitted at different provider timestamps' do
    first_payload = connection_payload('2026-07-23T10:00:00.000Z')
    second_payload = connection_payload('2026-07-23T10:05:00.000Z')

    first_key = described_class.new(provisioning: provisioning, payload: first_payload).generate
    second_key = described_class.new(provisioning: provisioning, payload: second_payload).generate

    expect(first_key).not_to eq(second_key)
  end

  it 'distinguishes delivery-state transitions for the same message' do
    sent_key = described_class.new(provisioning: provisioning, payload: status_payload('SENT')).generate
    delivered_key = described_class.new(provisioning: provisioning, payload: status_payload('DELIVERED')).generate

    expect(sent_key).not_to eq(delivered_key)
  end

  it 'deduplicates a repeated delivery state for the same message' do
    first_key = described_class.new(provisioning: provisioning, payload: status_payload('DELIVERED')).generate
    duplicate_key = described_class.new(provisioning: provisioning, payload: status_payload('DELIVERED')).generate

    expect(first_key).to eq(duplicate_key)
  end

  def connection_payload(date_time)
    {
      event: 'connection.update',
      instance: provisioning.instance_name,
      date_time: date_time,
      data: {
        state: 'open',
        wuid: '5511999999999@s.whatsapp.net',
        profileName: 'Support'
      }
    }
  end

  def status_payload(status)
    {
      event: 'messages.update',
      instance: provisioning.instance_name,
      data: {
        keyId: 'provider-message-id',
        status: status
      }
    }
  end
end
