class Email::CampaignDeliveryService
  UNSUBSCRIBED_KEY = 'email_unsubscribed'.freeze
  MAX_ERROR_LENGTH = 1000

  pattr_initialize [:delivery!]

  def perform
    return if delivery.queued? || delivery.skipped? || delivery.failed?
    return mark_skipped! unless deliverable?
    return unless claim_delivery!

    create_conversation_and_message!
    delivery.update!(status: :queued, processed_at: Time.current, error_message: nil)
  rescue StandardError => e
    mark_failed!(e)
  ensure
    complete_campaign_if_finished!
  end

  private

  delegate :campaign, :contact, to: :delivery

  def deliverable?
    contact.account_id == campaign.account_id &&
      contact.email.present? &&
      !contact.blocked? &&
      !ActiveModel::Type::Boolean.new.cast(contact.additional_attributes[UNSUBSCRIBED_KEY])
  end

  def claim_delivery!
    delivery.with_lock do
      retry_stale_processing = delivery.processing? && delivery.updated_at < 15.minutes.ago
      next false unless delivery.pending? || retry_stale_processing

      delivery.update!(status: :processing)
      true
    end
  end

  def mark_skipped!
    delivery.update!(status: :skipped, processed_at: Time.current)
  end

  def mark_failed!(error)
    Rails.logger.error(
      "[Email Campaign #{campaign.id}] Delivery #{delivery.id} failed: #{error.class}: #{error.message}"
    )
    delivery.update!(
      status: :failed,
      processed_at: Time.current,
      error_message: "#{error.class}: #{error.message}".truncate(MAX_ERROR_LENGTH)
    )
  end

  def create_conversation_and_message!
    ActiveRecord::Base.transaction do
      conversation = delivery.conversation || existing_campaign_conversation || create_conversation!
      delivery.update!(conversation: conversation) unless delivery.conversation_id == conversation.id
      create_message!(conversation) unless conversation.messages.outgoing.exists?
    end
  end

  def existing_campaign_conversation
    campaign.conversations.find_by(contact_id: contact.id)
  end

  def create_conversation!
    contact_inbox = ContactInboxBuilder.new(contact: contact, inbox: campaign.inbox).perform
    Conversation.create!(
      account: campaign.account,
      inbox: campaign.inbox,
      contact: contact,
      contact_inbox: contact_inbox,
      campaign: campaign,
      assignee: campaign.sender,
      additional_attributes: {
        'mail_subject' => processed_subject
      }
    )
  end

  def create_message!(conversation)
    Messages::MessageBuilder.new(
      campaign.sender,
      conversation,
      ActionController::Parameters.new(
        content: processed_content,
        campaign_id: campaign.id,
        to_emails: contact.email
      )
    ).perform
  end

  def processed_subject
    liquid_service.call(campaign.template_params['subject'])
  end

  def processed_content
    "#{liquid_service.call(campaign.message)}\n\n---\n#{unsubscribe_text}"
  end

  def liquid_service
    @liquid_service ||= Liquid::CampaignTemplateService.new(
      campaign: campaign,
      contact: contact
    )
  end

  def unsubscribe_text
    "Não deseja mais receber estes e-mails? Cancele o recebimento: #{unsubscribe_url}"
  end

  def unsubscribe_url
    base_url = ENV.fetch('FRONTEND_URL').delete_suffix('/')
    token = Email::UnsubscribeTokenService.generate(contact)
    "#{base_url}/email/unsubscribe/#{ERB::Util.url_encode(token)}"
  end

  def complete_campaign_if_finished!
    return unless campaign.processing?
    return if campaign.campaign_deliveries.unfinished.exists?

    campaign.completed!
  end
end
