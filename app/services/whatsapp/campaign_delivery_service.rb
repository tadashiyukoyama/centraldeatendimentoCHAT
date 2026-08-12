require 'digest'

class Whatsapp::CampaignDeliveryService
  UNSUBSCRIBED_KEY = 'whatsapp_marketing_unsubscribed'.freeze
  MAX_ERROR_LENGTH = 1000

  pattr_initialize [:delivery!]

  def perform
    return if delivery.queued? || delivery.skipped? || delivery.failed?
    return mark_skipped!(ineligible_reason) unless deliverable?
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
    ineligible_reason.blank?
  end

  def ineligible_reason
    return 'contact belongs to another account' unless contact.account_id == campaign.account_id
    return 'campaign is not an Evolution WhatsApp campaign' unless evolution_campaign?
    return 'contact is blocked' if contact.blocked?
    return 'contact opted out of WhatsApp marketing' if whatsapp_marketing_unsubscribed?
    return 'contact name is required for personalization' if contact.name.blank?
    return 'contact phone number is required' if contact.phone_number.blank?

    nil
  end

  def evolution_campaign?
    campaign.inbox.inbox_type == 'Whatsapp' && campaign.inbox.channel.provider == 'evolution'
  end

  def whatsapp_marketing_unsubscribed?
    ActiveModel::Type::Boolean.new.cast(contact.additional_attributes.to_h[UNSUBSCRIBED_KEY])
  end

  def claim_delivery!
    delivery.with_lock do
      retry_stale_processing = delivery.processing? && delivery.updated_at < 15.minutes.ago
      next false unless delivery.pending? || retry_stale_processing

      delivery.update!(status: :processing)
      true
    end
  end

  def mark_skipped!(reason)
    delivery.update!(status: :skipped, processed_at: Time.current, error_message: reason)
  end

  def mark_failed!(error)
    Rails.logger.error(
      "[Evolution Campaign #{campaign.id}] Delivery #{delivery.id} failed: #{error.class}: #{error.message}"
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
        'campaign_delivery_id' => delivery.id,
        'campaign_variant' => selected_variant_index + 1
      }
    )
  end

  def create_message!(conversation)
    Messages::MessageBuilder.new(
      campaign.sender,
      conversation,
      ActionController::Parameters.new(
        content: processed_content,
        campaign_id: campaign.id
      )
    ).perform
  end

  def processed_content
    content = liquid_service.call(selected_message_variant)
    "#{content}\n\nSe não quiser mais receber mensagens, responda SAIR."
  end

  def selected_message_variant
    message_variants.fetch(selected_variant_index)
  end

  def selected_variant_index
    @selected_variant_index ||= Digest::SHA256.hexdigest("#{campaign.id}:#{contact.id}").to_i(16) % message_variants.size
  end

  def message_variants
    @message_variants ||= [campaign.message, *Array(campaign.trigger_rules['message_variants'])]
                          .filter_map { |content| content.to_s.strip.presence }
                          .uniq
                          .first(Campaigns::EvolutionWhatsappValidatable::EVOLUTION_MAX_MESSAGE_VARIANTS)
  end

  def liquid_service
    @liquid_service ||= Liquid::CampaignTemplateService.new(campaign: campaign, contact: contact)
  end

  def complete_campaign_if_finished!
    return unless campaign.processing?
    return if campaign.campaign_deliveries.unfinished.exists?

    campaign.completed!
  end
end
