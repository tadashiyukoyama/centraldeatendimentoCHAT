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
end
