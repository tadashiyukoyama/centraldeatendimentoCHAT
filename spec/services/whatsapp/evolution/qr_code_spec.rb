require 'rails_helper'

RSpec.describe Whatsapp::Evolution::QrCode do
  let(:png) { "\x89PNG\r\n\x1A\ncontent".b }

  it 'returns a normalized PNG data URL' do
    result = described_class.normalize(Base64.strict_encode64(png))

    expect(result).to eq("data:image/png;base64,#{Base64.strict_encode64(png)}")
  end

  it 'rejects non-PNG remote content' do
    expect do
      described_class.normalize(Base64.strict_encode64('<svg></svg>'))
    end.to raise_error(
      Whatsapp::Evolution::ApiClient::Error,
      'Evolution QR Code response is invalid'
    )
  end
end
