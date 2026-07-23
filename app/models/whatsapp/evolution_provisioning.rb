class Whatsapp::EvolutionProvisioning < ApplicationRecord
  self.table_name = 'whatsapp_evolution_provisionings'

  WAITING_QR_SOURCE_STATUSES = %w[provisioning waiting_qr disconnected].freeze
  CONNECTING_SOURCE_STATUSES = %w[provisioning waiting_qr connecting disconnected].freeze
  DISCONNECTED_SOURCE_STATUSES = %w[provisioning waiting_qr connecting connected disconnected].freeze
  FAILURE_SOURCE_STATUSES = %w[provisioning waiting_qr connecting connected disconnected failed].freeze

  belongs_to :account
  belongs_to :whatsapp_channel, class_name: 'Channel::Whatsapp', optional: true
  has_many :events,
           class_name: 'Whatsapp::EvolutionEvent',
           foreign_key: :provisioning_id,
           inverse_of: :provisioning,
           dependent: :delete_all

  encrypts :instance_token, :webhook_secret if Chatwoot.encryption_configured?

  enum status: {
    provisioning: 0,
    waiting_qr: 1,
    connecting: 2,
    connected: 3,
    disconnected: 4,
    failed: 5,
    deleting: 6,
    deleted: 7
  }

  validates :public_id, :inbox_name, :instance_name, :instance_token, :webhook_secret, :expires_at, presence: true
  validates :public_id, :instance_name, uniqueness: true
  validates :whatsapp_channel_id, uniqueness: true, allow_nil: true
  validates :inbox_name, length: { maximum: 100 }
  validates :instance_name, format: { with: /\A[a-z0-9-]+\z/ }, length: { maximum: 64 }
  validates :connected_number, format: { with: /\A\+\d{6,15}\z/ }, allow_nil: true

  scope :active, -> { where.not(status: statuses.values_at(:deleting, :deleted)) }
  scope :expired_pending, lambda {
    where(status: statuses.values_at(:provisioning, :waiting_qr, :connecting))
      .where(expires_at: ...Time.current)
  }

  before_destroy :teardown_remote_instance, unless: :deleted?

  def expired?
    expires_at.past? && whatsapp_channel_id.nil?
  end

  def inbox
    whatsapp_channel&.inbox
  end

  def mark_waiting_for_qr!(seen_at: Time.current)
    transition_status!(:waiting_qr, from: WAITING_QR_SOURCE_STATUSES, last_seen_at: seen_at)
  end

  def mark_connecting!(seen_at: Time.current)
    transition_status!(:connecting, from: CONNECTING_SOURCE_STATUSES, last_seen_at: seen_at)
  end

  def mark_disconnected!(seen_at: Time.current)
    transition_status!(:disconnected, from: DISCONNECTED_SOURCE_STATUSES, last_seen_at: seen_at)
  end

  def mark_deleting!
    transition_status!(:deleting, from: self.class.statuses.keys - %w[deleted])
  end

  def mark_deleted!(seen_at: Time.current)
    transition_status!(
      :deleted,
      from: %w[deleting],
      whatsapp_channel: nil,
      last_seen_at: seen_at
    )
  end

  def record_failure!(code:, message:)
    transition_status!(
      :failed,
      from: FAILURE_SOURCE_STATUSES,
      last_error_code: code.to_s.first(100),
      last_error_message: message.to_s.first(500)
    )
  end

  def record_teardown_failure!(code:, message:)
    transition_status!(
      :failed,
      from: %w[deleting],
      last_error_code: code.to_s.first(100),
      last_error_message: message.to_s.first(500)
    )
  end

  private

  def transition_status!(target_status, from:, **attributes)
    allowed_statuses = Array(from).map(&:to_s)

    with_lock do
      next false unless status.in?(allowed_statuses)

      update!(attributes.merge(status: target_status))
    end
  end

  def teardown_remote_instance
    Whatsapp::Evolution::TeardownService.new(self).perform
  end
end
