require 'rails_helper'

RSpec.describe PrivacyRequestCleanupJob do
  def create_request(status:, created_at: Time.current, completed_at: nil, metadata_expires_at: 730.days.from_now)
    request_record = PrivacyRequest.new(
      email: 'titular@example.com',
      request_type: :access,
      status: status,
      completed_at: completed_at,
      metadata_expires_at: metadata_expires_at
    ).prepare_submission!
    request_record.save!
    request_record.update!(created_at: created_at, completed_at: completed_at, metadata_expires_at: metadata_expires_at)
    request_record
  end

  it 'expires unverified requests, purges closed sensitive data, and retains current metadata' do
    expired_unverified = create_request(status: :pending_verification, created_at: 8.days.ago)
    closed = create_request(status: :completed, completed_at: 91.days.ago)
    current = create_request(status: :verified)

    described_class.perform_now

    expect(PrivacyRequest.exists?(expired_unverified.id)).to be(false)
    expect(closed.reload).to have_attributes(email: nil, details: nil)
    expect(closed.purged_at).to be_present
    expect(PrivacyRequest.exists?(current.id)).to be(true)
  end

  it 'deletes only minimum metadata after 730 days' do
    expired_metadata = create_request(
      status: :completed,
      completed_at: 731.days.ago,
      metadata_expires_at: 1.day.ago
    )

    described_class.perform_now

    expect(PrivacyRequest.exists?(expired_metadata.id)).to be(false)
  end
end
