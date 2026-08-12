module Campaigns::EvolutionWhatsappValidatable
  extend ActiveSupport::Concern

  EVOLUTION_DELIVERY_INTERVAL_RANGE = (4..45)
  EVOLUTION_MAX_MESSAGE_VARIANTS = 3
  EVOLUTION_MAX_MESSAGE_LENGTH = 4000
  CONTACT_NAME_LIQUID_PATTERN = /{{\s*contact\.name\s*}}/i

  included do
    validate :validate_whatsapp_campaign
  end

  private

  def validate_whatsapp_campaign
    return unless inbox&.inbox_type == 'Whatsapp'

    validate_whatsapp_provider
    validate_evolution_campaign if inbox.channel.provider == 'evolution'
  end

  def validate_whatsapp_provider
    return if %w[whatsapp_cloud evolution].include?(inbox.channel.provider)

    errors.add(:inbox_id, 'must use a supported WhatsApp inbox for campaigns')
  end

  def validate_whatsapp_audience
    label_ids = campaign_audience_label_ids
    valid_label_count = account.labels.where(id: label_ids).count
    return if label_ids.any? && valid_label_count == label_ids.size

    errors.add(:audience, 'must include at least one valid account label')
  end

  def validate_evolution_campaign
    validate_whatsapp_audience
    validate_evolution_sender
    validate_evolution_delivery_interval
    validate_evolution_recipient_permission
    validate_evolution_messages
  end

  def validate_evolution_sender
    errors.add(:sender, 'is required') if sender.blank?
  end

  def validate_evolution_delivery_interval
    rules = trigger_rules.to_h
    minimum = Integer(rules['delivery_interval_min_minutes'], exception: false)
    maximum = Integer(rules['delivery_interval_max_minutes'], exception: false)

    return validate_configured_evolution_delivery_range(minimum, maximum) if minimum || maximum

    legacy_interval = Integer(rules['delivery_interval_minutes'], exception: false)
    return if persisted? && legacy_interval && EVOLUTION_DELIVERY_INTERVAL_RANGE.cover?(legacy_interval)

    errors.add(:trigger_rules, 'delivery interval range must be between 4 and 45 minutes')
  end

  def validate_configured_evolution_delivery_range(minimum, maximum)
    unless valid_evolution_delivery_interval?(minimum) && valid_evolution_delivery_interval?(maximum)
      errors.add(:trigger_rules, 'delivery interval range must be between 4 and 45 minutes')
      return
    end

    errors.add(:trigger_rules, 'maximum delivery interval must be greater than minimum') unless maximum > minimum
  end

  def valid_evolution_delivery_interval?(interval)
    interval && EVOLUTION_DELIVERY_INTERVAL_RANGE.cover?(interval)
  end

  def validate_evolution_recipient_permission
    return if ActiveModel::Type::Boolean.new.cast(trigger_rules.to_h['lawful_basis_confirmed'])

    errors.add(:trigger_rules, 'recipient permission or lawful basis must be confirmed')
  end

  def validate_evolution_messages
    variants = evolution_message_variants
    if variants.size > EVOLUTION_MAX_MESSAGE_VARIANTS
      errors.add(:trigger_rules, "supports at most #{EVOLUTION_MAX_MESSAGE_VARIANTS} message variants")
    end

    variants.first(EVOLUTION_MAX_MESSAGE_VARIANTS).each do |content|
      errors.add(:message, 'must include {{contact.name}} for Evolution campaigns') unless content.match?(CONTACT_NAME_LIQUID_PATTERN)
      errors.add(:message, "must be at most #{EVOLUTION_MAX_MESSAGE_LENGTH} characters") if content.length > EVOLUTION_MAX_MESSAGE_LENGTH
    end
  end

  def evolution_message_variants
    [message, *Array(trigger_rules.to_h['message_variants'])]
      .filter_map { |content| content.to_s.strip.presence }
      .uniq
  end
end
