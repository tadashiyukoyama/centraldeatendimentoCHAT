require 'rails_helper'

RSpec.describe Whatsapp::EvolutionProvisioning do
  let(:provisioning) { create(:whatsapp_evolution_provisioning) }

  it 'refreshes stale state before a serialized lifecycle transition' do
    stale_provisioning = described_class.find(provisioning.id)
    provisioning.update!(status: :connecting, last_seen_at: Time.current)

    transitioned = stale_provisioning.mark_waiting_for_qr!

    expect(transitioned).to be(false)
    expect(stale_provisioning).to be_connecting
  end

  it 'records a failure from a stale instance without raising a locking error' do
    stale_provisioning = described_class.find(provisioning.id)
    provisioning.update!(status: :connecting, last_seen_at: Time.current)

    stale_provisioning.record_failure!(code: 'provider_failure', message: 'Sanitized failure')

    expect(stale_provisioning).to be_failed
    expect(stale_provisioning.last_error_code).to eq('provider_failure')
  end

  it 'does not let a concurrent operational failure reopen a deleting provisioning' do
    provisioning.update!(status: :deleting)

    transitioned = provisioning.record_failure!(code: 'provider_failure', message: 'Sanitized failure')

    expect(transitioned).to be(false)
    expect(provisioning).to be_deleting
  end

  it 'allows teardown itself to record a sanitized failure' do
    provisioning.update!(status: :deleting)

    transitioned = provisioning.record_teardown_failure!(code: 'teardown_failed', message: 'Sanitized failure')

    expect(transitioned).to be(true)
    expect(provisioning).to be_failed
    expect(provisioning.last_error_code).to eq('teardown_failed')
  end
end
