class Email::OneoffCampaignService
  DELIVERY_INTERVAL = 2.seconds

  pattr_initialize [:campaign!]

  def perform
    validate_campaign!
    create_delivery_snapshot!
    enqueue_pending_deliveries
    complete_campaign_if_finished!
  end

  private

  def validate_campaign!
    raise "Invalid campaign #{campaign.id}" unless campaign.inbox.inbox_type == 'Email' && campaign.one_off?
    raise 'Completed Campaign' if campaign.completed?
  end

  def create_delivery_snapshot!
    audience_contacts.find_each do |contact|
      campaign.campaign_deliveries.find_or_create_by!(contact: contact)
    end
  end

  def enqueue_pending_deliveries
    campaign.campaign_deliveries.pending.order(:id).find_each.with_index do |delivery, index|
      Email::CampaignDeliveryJob
        .set(wait: index * DELIVERY_INTERVAL)
        .perform_later(delivery.id)
    end
  end

  def audience_contacts
    return campaign.account.contacts.none if audience_label_names.empty?

    campaign.account.contacts
            .tagged_with(audience_label_names, any: true)
            .where(blocked: false)
            .where.not(email: [nil, ''])
  end

  def audience_label_names
    @audience_label_names ||= begin
      label_ids = campaign.audience.filter_map do |audience|
        audience['id'] if audience['type'] == 'Label'
      end
      campaign.account.labels.where(id: label_ids).pluck(:title)
    end
  end

  def complete_campaign_if_finished!
    campaign.completed! unless campaign.campaign_deliveries.unfinished.exists?
  end
end
