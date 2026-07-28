class Email::CampaignDeliveryJob < ApplicationJob
  queue_as :low

  def perform(delivery_id)
    delivery = CampaignDelivery.find_by(id: delivery_id)
    return if delivery.blank?

    Email::CampaignDeliveryService.new(delivery: delivery).perform
  end
end
