require 'digest'

class PrivacyRequest < ApplicationRecord
  include PrivacyRequestLabels

  VERIFICATION_TTL = 24.hours
  UNVERIFIED_RETENTION = 7.days
  SENSITIVE_RETENTION = 90.days
  METADATA_RETENTION = 730.days
  RESPONSE_DEADLINE = 15.days
  belongs_to :account, optional: true
  has_many :events, class_name: 'PrivacyRequestEvent', dependent: :destroy

  encrypts :email
  encrypts :details
  encrypts :resolution_notes

  enum request_type: {
    access: 0,
    correction: 1,
    portability: 2,
    deletion: 3,
    objection: 4,
    consent_withdrawal: 5
  }, _prefix: true

  enum status: {
    pending_verification: 0,
    verified: 1,
    in_review: 2,
    completed: 3,
    rejected: 4
  }, _prefix: true

  validates :protocol, :verification_token_digest, :status_token_digest, :verification_expires_at, presence: true
  validates :request_type, :status, presence: true
  validates :email, presence: true, unless: :purged?
  validates :protocol, :verification_token_digest, :status_token_digest, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :email, length: { maximum: 254 }, allow_blank: true
  validates :details, length: { maximum: 5_000 }, allow_blank: true
  validates :resolution_notes, length: { maximum: 5_000 }, allow_blank: true
  validate :validate_subprocessor_actions

  scope :unverified_expired, lambda {
    status_pending_verification.where('created_at < ?', UNVERIFIED_RETENTION.ago)
  }
  scope :sensitive_data_expired, lambda {
    where(status: %i[completed rejected], purged_at: nil).where('completed_at < ?', SENSITIVE_RETENTION.ago)
  }
  scope :metadata_expired, -> { where('metadata_expires_at < ?', Time.current) }

  attr_reader :raw_verification_token, :raw_status_token

  def prepare_submission!
    self.protocol ||= generate_protocol
    @raw_verification_token = SecureRandom.urlsafe_base64(32)
    @raw_status_token = SecureRandom.urlsafe_base64(32)
    self.verification_token_digest = token_digest(@raw_verification_token)
    self.status_token_digest = token_digest(@raw_status_token)
    self.verification_expires_at = VERIFICATION_TTL.from_now
    self.metadata_expires_at = METADATA_RETENTION.from_now
    self
  end

  def verify_token!(raw_token)
    with_lock do
      next false unless status_pending_verification?
      next false if verification_expires_at.past?
      next false unless token_matches?(verification_token_digest, raw_token)

      transition_to!(:verified)
      update!(verified_at: Time.current, due_at: RESPONSE_DEADLINE.from_now)
      true
    end
  end

  def status_token_valid?(raw_token)
    token_matches?(status_token_digest, raw_token)
  end

  def verification_token_valid?(raw_token)
    status_pending_verification? && verification_expires_at.future? && token_matches?(verification_token_digest, raw_token)
  end

  def transition_to!(new_status, actor: nil, notes: nil, subprocessor_actions: nil)
    new_status = new_status.to_s
    unless allowed_transitions.fetch(status).include?(new_status)
      raise ArgumentError, "Invalid privacy request transition: #{status} -> #{new_status}"
    end

    self.class.transaction do
      from_status = status
      update!(transition_attributes(new_status, notes, subprocessor_actions))
      create_transition_event!(from_status, new_status, actor, notes, subprocessor_actions)
    end
  end

  def link_account!(new_account, actor: nil)
    return if account_id == new_account.id

    self.class.transaction do
      update!(account: new_account)
      events.create!(
        event_type: 'account_linked',
        from_status: status,
        to_status: status,
        actor: actor,
        metadata: { 'account_id' => new_account.id }
      )
    end
  end

  def purge_sensitive_data!
    self.class.transaction do
      update!(email: nil, details: nil, resolution_notes: nil, purged_at: Time.current)
      events.create!(event_type: 'sensitive_data_purged', from_status: status, to_status: status)
    end
  end

  private

  def generate_protocol
    loop do
      candidate = "AC-#{Time.current.utc.strftime('%Y%m%d')}-#{SecureRandom.hex(6).upcase}"
      break candidate unless self.class.exists?(protocol: candidate)
    end
  end

  def token_digest(raw_token)
    Digest::SHA256.hexdigest(raw_token.to_s)
  end

  def token_matches?(digest, raw_token)
    return false if digest.blank? || raw_token.blank?

    candidate = token_digest(raw_token)
    ActiveSupport::SecurityUtils.secure_compare(digest, candidate)
  end

  def purged?
    purged_at.present?
  end

  def validate_subprocessor_actions
    actions = subprocessor_actions
    return if actions.is_a?(Array) && actions.size <= 50 && actions.all? { |action| action.is_a?(String) && action.length <= 500 }

    errors.add(:subprocessor_actions, 'must contain at most 50 text entries of 500 characters')
  end

  def transition_metadata(notes, actions)
    metadata = {}
    if notes.present?
      metadata['resolution_notes_present'] = true
      metadata['resolution_notes_sha256'] = Digest::SHA256.hexdigest(notes.to_s)
    end
    unless actions.nil?
      metadata['subprocessor_actions_count'] = actions.size
      metadata['subprocessor_actions_sha256'] = Digest::SHA256.hexdigest(actions.join("\n"))
    end
    metadata
  end

  def transition_attributes(new_status, notes, actions)
    attributes = { status: new_status }
    attributes[:resolution_notes] = notes if notes.present?
    attributes[:subprocessor_actions] = actions unless actions.nil?
    return attributes unless %w[completed rejected].include?(new_status)

    attributes.merge(completed_at: Time.current, metadata_expires_at: METADATA_RETENTION.from_now)
  end

  def create_transition_event!(from_status, new_status, actor, notes, actions)
    events.create!(
      event_type: new_status == 'verified' ? 'email_verified' : 'status_changed',
      from_status: from_status,
      to_status: new_status,
      actor: actor,
      metadata: transition_metadata(notes, actions)
    )
  end

  def allowed_transitions
    {
      'pending_verification' => ['verified'],
      'verified' => %w[in_review completed rejected],
      'in_review' => %w[completed rejected],
      'completed' => [],
      'rejected' => []
    }
  end
end
