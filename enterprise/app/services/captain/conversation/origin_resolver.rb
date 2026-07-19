class Captain::Conversation::OriginResolver
  ORIGINS = %w[campaign link spontaneous].freeze
  ORIGIN_ATTRIBUTE = 'captain_origin'.freeze

  def initialize(conversation)
    @conversation = conversation
  end

  def perform
    return stored_origin if stored_origin.present?

    origin = resolve_origin
    persist_origin(origin)
    origin
  end

  private

  def stored_origin
    value = @conversation.additional_attributes.to_h[ORIGIN_ATTRIBUTE].to_s
    value if ORIGINS.include?(value)
  end

  def resolve_origin
    return 'campaign' if campaign_origin?
    return 'link' if link_origin?

    'spontaneous'
  end

  def campaign_origin?
    return true if @conversation.campaign_id.present?

    @conversation.messages
                 .where(message_type: :outgoing)
                 .where("additional_attributes ->> 'campaign_id' IS NOT NULL")
                 .exists?
  end

  def link_origin?
    return false unless @conversation.inbox

    @conversation.inbox.inbox_type == 'Website'
  end

  def persist_origin(origin)
    attributes = @conversation.additional_attributes.to_h
    attributes[ORIGIN_ATTRIBUTE] = origin
    @conversation.update!(additional_attributes: attributes)

    Rails.logger.info(
      "[CAPTAIN][Origin] conversation=#{@conversation.display_id} " \
      "origin=#{origin} channel=#{@conversation.inbox&.inbox_type} " \
      "campaign_id=#{@conversation.campaign_id || 'none'}"
    )
  end
end
