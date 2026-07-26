class Captain::PaymentNotice < ApplicationRecord
  self.table_name = 'captain_payment_notices'

  belongs_to :account
  belongs_to :assistant, class_name: 'Captain::Assistant'
  belongs_to :conversation, class_name: '::Conversation'
  belongs_to :contact, class_name: '::Contact'
  belongs_to :verified_by, class_name: 'User', optional: true

  enum status: { pending_verification: 0, confirmed: 1, rejected: 2, cancelled: 3 }

  validates :currency, :idempotency_key, presence: true
  validates :currency, format: { with: /\A[A-Z]{3}\z/ }
  validates :idempotency_key, uniqueness: { scope: :account_id }
  validates :amount_cents, numericality: { greater_than: 0 }, allow_nil: true
  validate :verification_is_auditable
  validate :external_reference_is_complete
  validate :related_records_share_account

  private

  def verification_is_auditable
    return unless confirmed? || rejected?

    errors.add(:verified_at, 'is required') if verified_at.blank?
    return if verified_by_id.present? || external_provider.present?

    errors.add(:base, 'verified_by or external_provider is required for a reviewed status')
  end

  def external_reference_is_complete
    return if external_provider.present? == external_id.present?

    errors.add(:external_provider, 'and external_id must be provided together')
  end

  def related_records_share_account
    validate_account_match(:assistant, assistant)
    validate_account_match(:conversation, conversation)
    validate_account_match(:contact, contact)
    return if verified_by_id.blank? || account&.users&.exists?(id: verified_by_id)

    errors.add(:verified_by, 'must belong to the same account')
  end

  def validate_account_match(attribute, record)
    errors.add(attribute, 'must belong to the same account') if record && record.account_id != account_id
  end
end
