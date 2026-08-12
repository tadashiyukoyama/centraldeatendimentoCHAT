# == Schema Information
#
# Table name: campaigns
#
#  id                                 :bigint           not null, primary key
#  audience                           :jsonb
#  campaign_status                    :integer          default("active"), not null
#  campaign_type                      :integer          default("ongoing"), not null
#  description                        :text
#  enabled                            :boolean          default(TRUE)
#  message                            :text             not null
#  scheduled_at                       :datetime
#  template_params                    :jsonb
#  title                              :string           not null
#  trigger_only_during_business_hours :boolean          default(FALSE)
#  trigger_rules                      :jsonb
#  created_at                         :datetime         not null
#  updated_at                         :datetime         not null
#  account_id                         :bigint           not null
#  display_id                         :integer          not null
#  inbox_id                           :bigint           not null
#  sender_id                          :integer
#
# Indexes
#
#  index_campaigns_on_account_id       (account_id)
#  index_campaigns_on_campaign_status  (campaign_status)
#  index_campaigns_on_campaign_type    (campaign_type)
#  index_campaigns_on_inbox_id         (inbox_id)
#  index_campaigns_on_scheduled_at     (scheduled_at)
#
class Campaign < ApplicationRecord
  include UrlHelper
  include Campaigns::EvolutionWhatsappValidatable
  validates :account_id, presence: true
  validates :inbox_id, presence: true
  validates :title, presence: true
  validates :message, presence: true
  validate :validate_campaign_inbox
  validate :validate_url
  validate :prevent_completed_campaign_from_update, on: :update
  validate :sender_must_belong_to_account
  validate :inbox_must_belong_to_account
  validate :validate_email_campaign

  belongs_to :account
  belongs_to :inbox
  belongs_to :sender, class_name: 'User', optional: true

  enum campaign_type: { ongoing: 0, one_off: 1 }
  # TODO : enabled attribute is unneccessary . lets move that to the campaign status with additional statuses like draft, disabled etc.
  enum campaign_status: { active: 0, completed: 1, processing: 2 }

  has_many :conversations, dependent: :nullify, autosave: true
  has_many :campaign_deliveries, dependent: :destroy

  before_validation :ensure_correct_campaign_attributes
  after_commit :set_display_id, unless: :display_id?
  after_destroy_commit :invalidate_filtered_unread_count_filters

  def trigger!
    return unless one_off?
    return unless feature_enabled?
    return unless mark_processing!

    execute_campaign
  end

  private

  def feature_enabled?
    inbox.inbox_type != 'Whatsapp' || account.feature_enabled?(:whatsapp_campaign)
  end

  def mark_processing!
    # Multiple scheduler jobs can pick the same active campaign; lock before flipping status to avoid duplicate sends.
    with_lock do
      next if completed? || processing?

      processing!
    end
  end

  def execute_campaign
    case inbox.inbox_type
    when 'Twilio SMS'
      Twilio::OneoffSmsCampaignService.new(campaign: self).perform
    when 'Sms'
      Sms::OneoffSmsCampaignService.new(campaign: self).perform
    when 'Whatsapp'
      Whatsapp::OneoffCampaignService.new(campaign: self).perform
    when 'Email'
      Email::OneoffCampaignService.new(campaign: self).perform
    end
  end

  def invalidate_filtered_unread_count_filters
    filters_changed = ::Conversations::UnreadCounts::FilteredCountInvalidator.new(account).conversation_changed!
    dispatch_account_cache_invalidated if filters_changed
  end

  def dispatch_account_cache_invalidated
    Rails.configuration.dispatcher.dispatch(ACCOUNT_CACHE_INVALIDATED, Time.zone.now, account: account, cache_keys: account.cache_keys)
  end

  def set_display_id
    reload
  end

  def validate_campaign_inbox
    return unless inbox

    supported_inboxes = ['Website', 'Twilio SMS', 'Sms', 'Whatsapp', 'Email']
    errors.add :inbox, 'Unsupported Inbox type' unless supported_inboxes.include? inbox.inbox_type
  end

  # TO-DO we clean up with better validations when campaigns evolve into more inboxes
  def ensure_correct_campaign_attributes
    return if inbox.blank?

    if ['Twilio SMS', 'Sms', 'Whatsapp', 'Email'].include?(inbox.inbox_type)
      self.campaign_type = 'one_off'
      self.scheduled_at ||= Time.now.utc
    else
      self.campaign_type = 'ongoing'
      self.scheduled_at = nil
    end
  end

  def validate_url
    return unless trigger_rules['url']

    use_http_protocol = trigger_rules['url'].starts_with?('http://') || trigger_rules['url'].starts_with?('https://')
    errors.add(:url, 'invalid') if inbox.inbox_type == 'Website' && !use_http_protocol
  end

  def inbox_must_belong_to_account
    return unless inbox

    return if inbox.account_id == account_id

    errors.add(:inbox_id, 'must belong to the same account as the campaign')
  end

  def sender_must_belong_to_account
    return unless sender

    return if account.users.exists?(id: sender.id)

    errors.add(:sender_id, 'must belong to the same account as the campaign')
  end

  def validate_email_campaign
    return unless inbox&.inbox_type == 'Email'

    validate_email_sender
    validate_email_subject
    validate_email_audience
    validate_email_recipient_permission
  end

  def validate_email_sender
    errors.add(:sender, 'is required') if sender.blank?
  end

  def validate_email_subject
    errors.add(:template_params, 'subject is required') if template_params&.dig('subject').blank?
  end

  def validate_email_recipient_permission
    return if ActiveModel::Type::Boolean.new.cast(template_params&.dig('lawful_basis_confirmed'))

    errors.add(:template_params, 'recipient permission must be confirmed')
  end

  def validate_email_audience
    label_ids = campaign_audience_label_ids
    valid_label_count = account.labels.where(id: label_ids).count
    return if label_ids.any? && valid_label_count == label_ids.size

    errors.add(:audience, 'must include at least one valid account label')
  end

  def campaign_audience_label_ids
    Array(audience)
      .select { |item| item['type'] == 'Label' }
      .pluck('id')
      .map(&:to_i)
      .uniq
  end

  def prevent_completed_campaign_from_update
    errors.add :status, 'The campaign is already completed' if !campaign_status_changed? && completed?
  end

  # creating db triggers
  trigger.before(:insert).for_each(:row) do
    "NEW.display_id := nextval('camp_dpid_seq_' || NEW.account_id);"
  end
end
