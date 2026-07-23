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
end
