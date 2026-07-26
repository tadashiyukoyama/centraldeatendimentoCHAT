require 'rails_helper'

RSpec.describe 'SuperAdmin privacy request queue', type: :request do
  let(:super_admin) { create(:super_admin) }
  let(:privacy_request) do
    PrivacyRequest.new(
      email: 'titular@example.com',
      request_type: :deletion,
      locale: 'pt_BR',
      status: :verified,
      verified_at: Time.current,
      due_at: 15.days.from_now
    ).prepare_submission!.tap(&:save!)
  end

  before { sign_in(super_admin, scope: :super_admin) }

  it 'lists verified requests without exposing token digests' do
    privacy_request

    get super_admin_privacy_requests_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(privacy_request.protocol)
    expect(response.body).not_to include(
      'titular@example.com',
      privacy_request.verification_token_digest,
      privacy_request.status_token_digest
    )

    get super_admin_privacy_request_path(privacy_request)
    expect(response.body).to include('titular@example.com')
    expect(response.body).not_to include(privacy_request.verification_token_digest, privacy_request.status_token_digest)
  end

  it 'records the operator and manual subprocessor actions during review' do
    account = create(:account)
    patch super_admin_privacy_request_path(privacy_request), params: {
      privacy_request: {
        account_id: account.id,
        status: 'in_review',
        resolution_notes: 'Identidade conferida.',
        subprocessor_actions: "Solicitar remoção ao provedor de e-mail\nRevisar backup"
      }
    }

    expect(response).to redirect_to(super_admin_privacy_request_path(privacy_request))
    expect(privacy_request.reload).to be_status_in_review
    expect(privacy_request.account).to eq(account)
    expect(privacy_request.subprocessor_actions).to eq(['Solicitar remoção ao provedor de e-mail', 'Revisar backup'])
    expect(privacy_request.events.last.actor).to eq(super_admin)
    expect(privacy_request.events.pluck(:event_type)).to include('account_linked', 'status_changed')
  end

  it 'rejects an invalid transition without changing the request' do
    patch super_admin_privacy_request_path(privacy_request), params: {
      privacy_request: { status: 'pending_verification' }
    }

    expect(response).to redirect_to(super_admin_privacy_request_path(privacy_request))
    expect(privacy_request.reload).to be_status_verified
  end
end
