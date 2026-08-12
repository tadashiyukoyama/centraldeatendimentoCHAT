class Whatsapp::Evolution::MarketingOptOutService
  UNSUBSCRIBED_KEY = Whatsapp::CampaignDeliveryService::UNSUBSCRIBED_KEY
  UNSUBSCRIBED_AT_KEY = 'whatsapp_marketing_unsubscribed_at'.freeze
  OPT_OUT_PATTERN = /\Asair[.!]?\z/i

  pattr_initialize [:contact!, :message!]

  def perform
    return false unless opt_out_message?
    return true if already_unsubscribed?

    contact.update!(
      additional_attributes: contact.additional_attributes.to_h.merge(
        UNSUBSCRIBED_KEY => true,
        UNSUBSCRIBED_AT_KEY => Time.current.iso8601
      )
    )
    true
  end

  private

  def opt_out_message?
    message.incoming? && message.content.to_s.strip.match?(OPT_OUT_PATTERN)
  end

  def already_unsubscribed?
    ActiveModel::Type::Boolean.new.cast(contact.additional_attributes.to_h[UNSUBSCRIBED_KEY])
  end
end
