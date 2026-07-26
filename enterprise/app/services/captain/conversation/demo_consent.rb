class Captain::Conversation::DemoConsent
  ACCEPTANCE_PATTERN = /\A\s*(?:sim|confirmo|pode(?: ser)?|claro|aceito|ok(?:ay)?|esta certo|ta certo)\b/i
  OFFER_PATTERN = /\b(?:demo|demonstracao)\b/i

  def initialize(conversation)
    @conversation = conversation
  end

  def confirmed_slot?(starts_at, timezone)
    messages = public_messages
    latest = messages.last
    offer = messages[-2]
    return false unless accepted_by_contact?(latest) && offered_by_assistant?(offer)

    offer_content = normalize(offer)
    slot_offered?(offer_content, starts_at, timezone)
  end

  private

  def public_messages
    Captain::Conversation::MessageContextWindow.new(@conversation).perform.reject(&:activity?)
  end

  def normalize(message)
    ActiveSupport::Inflector.transliterate(message.content_for_llm.to_s).downcase
  end

  def accepted_by_contact?(message)
    message&.incoming? &&
      message.sender_type == 'Contact' &&
      normalize(message).match?(ACCEPTANCE_PATTERN)
  end

  def offered_by_assistant?(message)
    message&.outgoing? && %w[Captain::Assistant AgentBot].include?(message.sender_type)
  end

  def slot_offered?(content, starts_at, timezone)
    content.match?(OFFER_PATTERN) &&
      includes_token?(content, date_tokens(starts_at, timezone)) &&
      includes_token?(content, time_tokens(starts_at, timezone))
  end

  def includes_token?(content, tokens)
    tokens.any? { |token| content.include?(token) }
  end

  def date_tokens(starts_at, timezone)
    local_time = starts_at.in_time_zone(timezone)
    [
      local_time.strftime('%d/%m/%Y'),
      local_time.strftime('%d/%m'),
      local_time.strftime('%Y-%m-%d')
    ]
  end

  def time_tokens(starts_at, timezone)
    local_time = starts_at.in_time_zone(timezone)
    hour = local_time.strftime('%H').to_i
    minute = local_time.strftime('%M')
    [
      local_time.strftime('%H:%M'),
      "#{hour}:#{minute}",
      "#{hour}h#{minute == '00' ? '' : minute}"
    ]
  end
end
