class Whatsapp::OneoffCampaignService
  pattr_initialize [:campaign!]

  def perform
    validate_campaign!
    return perform_evolution_campaign if evolution_provider?

    process_cloud_audience(extract_audience_labels)
    campaign.completed!
  end

  private

  delegate :inbox, to: :campaign
  delegate :channel, to: :inbox

  def validate_campaign_type!
    raise "Invalid campaign #{campaign.id}" unless whatsapp_campaign? && campaign.one_off?
  end

  def whatsapp_campaign?
    campaign.inbox.inbox_type == 'Whatsapp'
  end

  def validate_campaign_status!
    raise 'Completed Campaign' if campaign.completed?
  end

  def validate_provider!
    return if %w[whatsapp_cloud evolution].include?(channel.provider)

    raise 'Supported WhatsApp provider required'
  end

  def validate_feature_flag!
    raise 'WhatsApp campaigns feature not enabled' unless campaign.account.feature_enabled?(:whatsapp_campaign)
  end

  def validate_campaign!
    validate_campaign_type!
    validate_campaign_status!
    validate_provider!
    validate_feature_flag!
  end

  def extract_audience_labels
    audience_label_ids = campaign.audience.select { |audience| audience['type'] == 'Label' }.pluck('id')
    campaign.account.labels.where(id: audience_label_ids).pluck(:title)
  end

  def process_cloud_contact(contact)
    Rails.logger.info "Processing contact: #{contact.name} (#{contact.phone_number})"

    if contact.phone_number.blank?
      Rails.logger.info "Skipping contact #{contact.name} - no phone number"
      return
    end

    if campaign.template_params.blank?
      Rails.logger.error "Skipping contact #{contact.name} - no template_params found for WhatsApp campaign"
      return
    end

    processed_template_params = process_liquid_template_params(contact)
    return if processed_template_params.nil?

    send_whatsapp_template_message(to: contact.phone_number, template_params: processed_template_params)
  end

  def process_cloud_audience(audience_labels)
    contacts = campaign.account.contacts.tagged_with(audience_labels, any: true)
    Rails.logger.info "Processing #{contacts.count} contacts for campaign #{campaign.id}"

    contacts.each { |contact| process_cloud_contact(contact) }

    Rails.logger.info "Campaign #{campaign.id} processing completed"
  end

  def process_liquid_template_params(contact)
    liquid_processor = Whatsapp::LiquidTemplateProcessorService.new(campaign: campaign, contact: contact)
    processed_template_params = liquid_processor.process_template_params(campaign.template_params)

    Rails.logger.info "Skipping contact #{contact.name} - liquid variables resolved to blank values" if processed_template_params.nil?

    processed_template_params
  rescue StandardError => e
    Rails.logger.error "Failed to process liquid template params for contact #{contact.name}: #{e.message}"
    nil
  end

  def send_whatsapp_template_message(to:, template_params:)
    processor = Whatsapp::TemplateProcessorService.new(
      channel: channel,
      template_params: template_params
    )

    name, namespace, lang_code, processed_parameters = processor.call

    return if name.blank?

    channel.send_template(to, {
                            name: name,
                            namespace: namespace,
                            lang_code: lang_code,
                            parameters: processed_parameters
                          }, nil)

  rescue StandardError => e
    Rails.logger.error "Failed to send WhatsApp template message to #{to}: #{e.message}"
    Rails.logger.error "Backtrace: #{e.backtrace.first(5).join('\n')}"
    # continue processing remaining contacts
    nil
  end

  def evolution_provider?
    channel.provider == 'evolution'
  end

  def perform_evolution_campaign
    create_evolution_delivery_snapshot!
    enqueue_evolution_deliveries
    campaign.completed! unless campaign.campaign_deliveries.unfinished.exists?
  end

  def create_evolution_delivery_snapshot!
    audience_contacts.find_each do |contact|
      campaign.campaign_deliveries.find_or_create_by!(contact: contact)
    end
  end

  def enqueue_evolution_deliveries
    first_delivery_at = Time.current
    campaign.campaign_deliveries.pending.order(:id).find_each.with_index do |delivery, index|
      scheduled_for = first_delivery_at + (index * evolution_delivery_interval_minutes).minutes
      delivery.update!(scheduled_for: scheduled_for)
      Whatsapp::CampaignDeliveryJob.set(wait_until: scheduled_for).perform_later(delivery.id)
    end
  end

  def audience_contacts
    return campaign.account.contacts.none if extract_audience_labels.empty?

    campaign.account.contacts.tagged_with(extract_audience_labels, any: true)
  end

  def evolution_delivery_interval_minutes
    campaign.trigger_rules.fetch('delivery_interval_minutes').to_i
  end
end
