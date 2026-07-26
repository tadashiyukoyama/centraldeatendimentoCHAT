require 'rails_helper'

RSpec.describe Captain::PaymentAmount, type: :service do
  it 'normalizes Brazilian and international decimal formats' do
    expect(described_class.to_cents('R$ 1.500,25')).to eq(150_025)
    expect(described_class.to_cents('150.25')).to eq(15_025)
    expect(described_class.to_cents('150')).to eq(15_000)
  end

  it 'rejects non-positive and malformed amounts' do
    expect { described_class.to_cents('-10,00') }.to raise_error(described_class::InvalidAmount)
    expect { described_class.to_cents('sem valor') }.to raise_error(described_class::InvalidAmount)
  end
end
