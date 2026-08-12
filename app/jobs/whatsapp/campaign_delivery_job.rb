class Whatsapp::CampaignDeliveryJob < ApplicationJob
  queue_as :low

  def perform(delivery_id)
    delivery = CampaignDelivery.find_by(id: delivery_id)
    return if delivery.blank?

    Whatsapp::CampaignDeliveryService.new(delivery: delivery).perform
  end
end
