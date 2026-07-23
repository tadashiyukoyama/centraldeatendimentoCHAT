require 'rails_helper'

RSpec.describe Whatsapp::Evolution::CleanupExpiredProvisioningsJob do
  it 'tears down only expired pending provisionings when the integration is enabled' do
    expired = create(:whatsapp_evolution_provisioning, expires_at: 1.minute.ago)
    create(:whatsapp_evolution_provisioning, expires_at: 10.minutes.from_now)
    teardown = instance_double(Whatsapp::Evolution::TeardownService, perform: true)
    allow(Whatsapp::Evolution::Configuration).to receive(:enabled?).and_return(true)
    allow(Whatsapp::Evolution::TeardownService).to receive(:new).and_return(teardown)

    described_class.perform_now

    expect(Whatsapp::Evolution::TeardownService).to have_received(:new).with(expired).once
    expect(teardown).to have_received(:perform).once
  end

  it 'does nothing while the integration is disabled' do
    create(:whatsapp_evolution_provisioning, expires_at: 1.minute.ago)
    allow(Whatsapp::Evolution::Configuration).to receive(:enabled?).and_return(false)
    allow(Whatsapp::Evolution::TeardownService).to receive(:new)

    described_class.perform_now

    expect(Whatsapp::Evolution::TeardownService).not_to have_received(:new)
  end
end
