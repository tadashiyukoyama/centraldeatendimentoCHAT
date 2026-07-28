require 'rails_helper'

RSpec.describe Email::UnsubscribeTokenService do
  let(:contact) { create(:contact) }

  it 'round trips a URL-safe signed token' do
    token = described_class.generate(contact)

    expect(token).to match(/\A[A-Za-z0-9_-]+\z/)
    expect(described_class.contact_for(token)).to eq(contact)
  end

  it 'rejects a tampered token' do
    token = described_class.generate(contact)

    expect(described_class.contact_for("#{token}x")).to be_nil
  end
end
