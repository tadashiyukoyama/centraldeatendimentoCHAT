require 'rails_helper'

RSpec.describe Whatsapp::Evolution::ConnectionSyncService do
  let(:provisioning) { create(:whatsapp_evolution_provisioning) }
  let(:client) { instance_double(Whatsapp::Evolution::ApiClient) }

  before do
    allow(Whatsapp::Evolution::ApiClient).to receive(:new)
      .with(provisioning: provisioning)
      .and_return(client)
  end

  it 'returns a validated QR Code while the instance is waiting for connection' do
    qr_code = Base64.strict_encode64("\x89PNG\r\n\x1A\ncontent".b)
    allow(client).to receive(:connection_state).and_return('instance' => { 'state' => 'close' })
    allow(client).to receive(:connect).and_return('base64' => qr_code)

    result = described_class.new(provisioning: provisioning).perform

    expect(result.provisioning).to be_waiting_qr
    expect(result.qr_code).to eq("data:image/png;base64,#{qr_code}")
  end

  it 'reconnects an existing inbox even after the original QR expiry time' do
    inbox = Whatsapp::Evolution::FinalizeProvisioningService.new(
      provisioning: provisioning,
      connected_number: '5511999999999@s.whatsapp.net'
    ).perform
    provisioning.update!(status: :disconnected, expires_at: 1.hour.ago)
    allow(client).to receive(:connection_state).and_return('instance' => { 'state' => 'open' })
    allow(client).to receive(:fetch_instance).and_return(
      'ownerJid' => '5511999999999@s.whatsapp.net'
    )

    result = described_class.new(provisioning: provisioning).perform

    expect(result.provisioning).to be_connected
    expect(result.provisioning.inbox).to eq(inbox)
    expect(result.qr_code).to be_nil
  end

  it 'refreshes a stale provisioning before applying the provider state' do
    stale_provisioning = Whatsapp::EvolutionProvisioning.find(provisioning.id)
    stale_client = instance_double(Whatsapp::Evolution::ApiClient)
    allow(Whatsapp::Evolution::ApiClient).to receive(:new)
      .with(provisioning: stale_provisioning)
      .and_return(stale_client)
    allow(stale_client).to receive(:connection_state).and_return('instance' => { 'state' => 'connecting' })
    allow(stale_client).to receive(:connect).and_return(
      'base64' => Base64.strict_encode64("\x89PNG\r\n\x1A\ncontent".b)
    )
    provisioning.update!(status: :waiting_qr, last_seen_at: Time.current)

    result = described_class.new(provisioning: stale_provisioning).perform

    expect(result.provisioning).to be_connecting
  end

  it 'does not reopen a provisioning that entered teardown concurrently' do
    allow(client).to receive(:connection_state).and_return('instance' => { 'state' => 'connecting' })
    allow(client).to receive(:connect)
    provisioning.update!(status: :deleting)

    expect do
      described_class.new(provisioning: provisioning).perform
    end.to raise_error(Whatsapp::Evolution::ApiClient::Error, 'Evolution provisioning is not available')

    expect(provisioning.reload).to be_deleting
    expect(client).not_to have_received(:connect)
  end
end
