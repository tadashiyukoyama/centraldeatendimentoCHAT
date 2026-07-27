class InstagramCommentAutomation < ApplicationRecord
  MAX_KEYWORDS = 20
  MAX_KEYWORD_LENGTH = 50
  MAX_PUBLIC_REPLY_LENGTH = 300
  MAX_PRIVATE_REPLY_LENGTH = 1_000
  TEMPLATE_VARIABLES = %w[campaign comment keyword username].freeze

  belongs_to :account
  belongs_to :inbox
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :updated_by, class_name: 'User', optional: true

  has_many :instagram_comment_events, dependent: :nullify

  audited associated_with: :account

  enum :match_type, { whole_word: 0, exact: 1, contains: 2 }

  scope :enabled, -> { where(enabled: true) }
  scope :in_precedence_order, -> { order(priority: :desc, id: :asc) }

  normalizes :name, with: ->(value) { value.to_s.squish }
  normalizes :media_id, :conversation_label, with: ->(value) { value.to_s.strip.presence }

  validates :name, presence: true, length: { maximum: 120 }, uniqueness: { scope: :inbox_id }
  validates :priority, inclusion: { in: -100..100 }
  validates :media_id, format: { with: /\A\d+\z/, allow_blank: true }
  validates :conversation_label,
            format: { with: /\A[a-z0-9][a-z0-9_-]*\z/, allow_blank: true },
            length: { maximum: 50 }
  validates :public_reply_template, length: { maximum: MAX_PUBLIC_REPLY_LENGTH }, if: :public_reply_enabled?
  validates :private_reply_template, length: { maximum: MAX_PRIVATE_REPLY_LENGTH }, if: :private_reply_enabled?
  validates :conversation_context, length: { maximum: 2_000 }, allow_blank: true

  validate :inbox_is_instagram
  validate :inbox_belongs_to_account
  validate :users_belong_to_account
  validate :normalize_and_validate_keywords
  validate :at_least_one_reply
  validate :reply_templates_present
  validate :valid_schedule
  validate :valid_templates

  def active_at?(time)
    (starts_at.blank? || starts_at <= time) && (ends_at.blank? || ends_at >= time)
  end

  private

  def inbox_is_instagram
    errors.add(:inbox, 'must be an Instagram inbox') if inbox.present? && !inbox.instagram?
  end

  def inbox_belongs_to_account
    return if inbox.blank? || account.blank? || inbox.account_id == account_id

    errors.add(:inbox, 'must belong to the same account')
  end

  def users_belong_to_account
    { created_by: created_by, updated_by: updated_by }.each do |attribute, user|
      next if user.blank? || account&.users&.exists?(id: user.id)

      errors.add(attribute, 'must belong to the same account')
    end
  end

  def normalize_and_validate_keywords
    normalized = Array(keywords).filter_map { |keyword| keyword.to_s.squish.presence }.uniq
    self.keywords = normalized

    errors.add(:keywords, "must contain between 1 and #{MAX_KEYWORDS} items") unless normalized.length.between?(1, MAX_KEYWORDS)
    return unless normalized.any? { |keyword| keyword.length > MAX_KEYWORD_LENGTH }

    errors.add(:keywords, "items must have at most #{MAX_KEYWORD_LENGTH} characters")
  end

  def at_least_one_reply
    return if public_reply_enabled? || private_reply_enabled?

    errors.add(:base, 'at least one reply channel must be enabled')
  end

  def reply_templates_present
    errors.add(:public_reply_template, 'is required') if public_reply_enabled? && public_reply_template.blank?
    errors.add(:private_reply_template, 'is required') if private_reply_enabled? && private_reply_template.blank?
  end

  def valid_schedule
    return if starts_at.blank? || ends_at.blank? || ends_at > starts_at

    errors.add(:ends_at, 'must be after the start time')
  end

  def valid_templates
    [public_reply_template, private_reply_template].compact.each do |source|
      Instagram::CommentAutomation::TemplateRenderer.validate!(source, allowed_variables: TEMPLATE_VARIABLES)
    rescue Instagram::CommentAutomation::TemplateRenderer::InvalidTemplate => e
      errors.add(:base, e.message)
    end
  end
end
