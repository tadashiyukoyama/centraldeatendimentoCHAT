require 'rails_helper'

RSpec.describe Whatsapp::Evolution::IncomingMessageService do
  let(:provisioning) { build(:whatsapp_evolution_provisioning) }
  let(:service) do
    described_class.new(
      inbox: build(:inbox),
      params: {},
      outgoing_echo: false,
      provisioning: provisioning
    )
  end
  let(:client) { instance_double(Whatsapp::Evolution::ApiClient) }

  before do
    allow(Whatsapp::Evolution::ApiClient).to receive(:new)
      .with(provisioning: provisioning)
      .and_return(client)
    allow(GlobalConfigService).to receive(:load)
      .with('MAXIMUM_FILE_UPLOAD_SIZE', 40)
      .and_return(1)
  end

  it 'rejects a media payload larger than the configured upload limit' do
    encoded = Base64.strict_encode64('a' * 1.megabyte)
    allow(client).to receive(:media_base64).and_return('base64' => "#{encoded}AAAA")

    result = service.send(
      :download_attachment_file,
      evolution_message: { key: { id: 'media-id' } }
    )

    expect(result).to be_nil
  end
end
