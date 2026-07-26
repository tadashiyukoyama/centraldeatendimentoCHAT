require 'rails_helper'

RSpec.describe Captain::PaymentNotice, type: :model do
  it 'requires an auditable source before confirming a payment notice' do
    notice = build(:captain_payment_notice, status: :confirmed, verified_at: Time.current)

    expect(notice).not_to be_valid
    expect(notice.errors[:base]).to include('verified_by or external_provider is required for a reviewed status')
  end

  it 'accepts a confirmation reviewed by an account user' do
    notice = build(:captain_payment_notice)
    reviewer = create(:user, account: notice.account)
    notice.assign_attributes(status: :confirmed, verified_at: Time.current, verified_by: reviewer)

    expect(notice).to be_valid
  end

  it 'requires a complete external provider reference' do
    notice = build(:captain_payment_notice, external_provider: 'erpnext', external_id: nil)

    expect(notice).not_to be_valid
    expect(notice.errors[:external_provider]).to include('and external_id must be provided together')
  end
end
