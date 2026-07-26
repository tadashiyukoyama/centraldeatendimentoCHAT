require 'rails_helper'

RSpec.describe PrivacyRequest do
  subject(:privacy_request) { described_class.new(email: 'titular@example.com', request_type: :access, details: 'Quero acessar meus dados.') }

  it 'stores only token digests and verifies the email once', :aggregate_failures do
    privacy_request.prepare_submission!
    verification_token = privacy_request.raw_verification_token
    status_token = privacy_request.raw_status_token
    privacy_request.save!

    expect(privacy_request.verification_token_digest).not_to eq(verification_token)
    expect(privacy_request.status_token_digest).not_to eq(status_token)
    expect(privacy_request.status_token_valid?(status_token)).to be(true)
    expect(privacy_request.verify_token!(verification_token)).to be(true)
    expect(privacy_request).to be_status_verified
    expect(privacy_request.verified_at).to be_present
    expect(privacy_request.due_at).to be_within(1.minute).of(15.days.from_now)
    expect(privacy_request.verify_token!(verification_token)).to be(false)
  end

  it 'expires email verification after 24 hours' do
    privacy_request.prepare_submission!
    token = privacy_request.raw_verification_token
    privacy_request.save!

    travel 25.hours do
      expect(privacy_request.verify_token!(token)).to be(false)
    end
  end

  it 'purges sensitive fields while preserving minimum protocol metadata' do
    privacy_request.prepare_submission!.save!
    privacy_request.update!(status: :completed, completed_at: 91.days.ago)

    privacy_request.purge_sensitive_data!

    expect(privacy_request.reload.email).to be_nil
    expect(privacy_request.details).to be_nil
    expect(privacy_request.protocol).to be_present
    expect(privacy_request.purged_at).to be_present
  end

  it 'preserves the request locale and renders public status labels' do
    privacy_request.locale = 'en'
    privacy_request.prepare_submission!.save!

    expect(privacy_request.status_label).to eq('Pending verification')
    expect(privacy_request.status_label('pt_BR')).to eq('Aguardando verificação')
    expect(privacy_request.request_type_label).to eq('Access')
    expect(privacy_request.request_type_label('pt_BR')).to eq('Acesso')
  end

  it 'records a non-sensitive audit digest for manual resolution work' do
    privacy_request.prepare_submission!.save!
    privacy_request.update!(status: :verified, verified_at: Time.current)

    privacy_request.transition_to!(
      :in_review,
      notes: 'Identidade conferida pelo operador.',
      subprocessor_actions: ['Solicitar exclusão ao provedor de e-mail']
    )

    event = privacy_request.events.order(:created_at).last
    expect(event.metadata).to include(
      'resolution_notes_present' => true,
      'subprocessor_actions_count' => 1
    )
    expect(event.metadata.fetch('resolution_notes_sha256')).to match(/\A[0-9a-f]{64}\z/)
    expect(event.metadata.fetch('subprocessor_actions_sha256')).to match(/\A[0-9a-f]{64}\z/)
    expect(event.metadata.to_json).not_to include('Identidade conferida', 'provedor de e-mail')
  end
end
