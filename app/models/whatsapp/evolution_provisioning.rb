class Whatsapp::EvolutionProvisioning < ApplicationRecord
  self.table_name = 'whatsapp_evolution_provisionings'

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

  def record_failure!(code:, message:)
    update!(
      status: :failed,
      last_error_code: code.to_s.first(100),
      last_error_message: message.to_s.first(500)
    )
  end

  private

  def teardown_remote_instance
    Whatsapp::Evolution::TeardownService.new(self).perform
  end
end
