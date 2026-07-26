class Captain::Appointment < ApplicationRecord
  self.table_name = 'captain_appointments'

  belongs_to :account
  belongs_to :assistant, class_name: 'Captain::Assistant'
  belongs_to :conversation, class_name: '::Conversation'
  belongs_to :contact, class_name: '::Contact'
  belongs_to :specialist, class_name: 'User', optional: true

  enum status: { scheduled: 0, completed: 1, cancelled: 2, no_show: 3 }

  validates :kind, :starts_at, :ends_at, :timezone, :idempotency_key, presence: true
  validates :specialist, presence: true, on: :create
  validates :kind, inclusion: { in: %w[demo] }
  validates :idempotency_key, uniqueness: { scope: :account_id }
  validate :ends_after_start
  validate :valid_timezone
  validate :external_reference_is_complete
  validate :related_records_share_account

  scope :active, -> { where(status: :scheduled) }
  scope :overlapping, lambda { |starts_at, ends_at|
    where('starts_at < ? AND ends_at > ?', ends_at, starts_at)
  }

  private

  def ends_after_start
    return if starts_at.blank? || ends_at.blank? || ends_at > starts_at

    errors.add(:ends_at, 'must be after starts_at')
  end

  def valid_timezone
    errors.add(:timezone, 'is invalid') if timezone.present? && ActiveSupport::TimeZone[timezone].nil?
  end

  def external_reference_is_complete
    return if external_provider.present? == external_id.present?

    errors.add(:external_provider, 'and external_id must be provided together')
  end

  def related_records_share_account
    validate_account_match(:assistant, assistant)
    validate_account_match(:conversation, conversation)
    validate_account_match(:contact, contact)
    return if specialist_id.blank? || account&.users&.exists?(id: specialist_id)

    errors.add(:specialist, 'must belong to the same account')
  end

  def validate_account_match(attribute, record)
    errors.add(attribute, 'must belong to the same account') if record && record.account_id != account_id
  end
end
