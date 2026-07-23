require 'rails_helper'

RSpec.describe Whatsapp::Evolution::FinalizeProvisioningService do
  let(:provisioning) { create(:whatsapp_evolution_provisioning, status: :connecting) }

  it 'creates one native WhatsApp channel and inbox after connection is proven' do
    inbox = described_class.new(
      provisioning: provisioning,
      connected_number: '5511999999999@s.whatsapp.net',
      profile_name: 'Support'
    ).perform

    provisioning.reload
    expect(provisioning).to be_connected
    expect(provisioning.connected_number).to eq('+5511999999999')
    expect(provisioning.whatsapp_channel.provider).to eq('evolution')
    expect(provisioning.whatsapp_channel.provider_config).to eq(
      'evolution_provisioning_id' => provisioning.id
    )
    expect(inbox.name).to eq(provisioning.inbox_name)
  end

  it 'is idempotent when the connection event is delivered twice' do
    service = described_class.new(
      provisioning: provisioning,
      connected_number: '5511999999999@s.whatsapp.net'
    )

    first_inbox = service.perform
    expect { service.perform }.not_to change(Inbox, :count)
    expect(service.perform).to eq(first_inbox)
  end

  it 'restores connected state on an existing channel without creating another inbox' do
    service = described_class.new(
      provisioning: provisioning,
      connected_number: '5511999999999@s.whatsapp.net'
    )
    inbox = service.perform
    provisioning.update!(status: :disconnected, expires_at: 1.hour.ago)

    expect { service.perform }.not_to change(Inbox, :count)
    expect(provisioning.reload).to be_connected
    expect(provisioning.inbox).to eq(inbox)
    expect(provisioning).not_to be_expired
  end
end
