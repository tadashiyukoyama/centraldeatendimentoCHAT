class Captain::Conversation::DemoConsent
  PENDING_KEY = 'captain_pending_demo_confirmation'.freeze
  CONFIRMATION_TTL = 24.hours
  ACCEPTANCE_PATTERN = /\A\s*(?:sim|confirmo|pode(?: ser)?|claro|aceito|ok(?:ay)?|esta certo|ta certo)\b/i

  def initialize(conversation)
    @conversation = conversation
  end

  def request_confirmation!(starts_at, duration_minutes, timezone)
    @conversation.update!(
      additional_attributes: @conversation.additional_attributes.to_h.merge(
        PENDING_KEY => {
          'starts_at' => starts_at.utc.iso8601,
          'duration_minutes' => Integer(duration_minutes),
          'timezone' => timezone,
          'requested_at' => Time.current.utc.iso8601,
          'requested_from_message_id' => latest_contact_message&.id
        }
      )
    )
  end

  def confirmed_slot?(starts_at, duration_minutes, timezone)
    pending = pending_confirmation
    return false unless pending_slot_matches?(pending, starts_at, duration_minutes, timezone)

    messages = public_messages
    latest = messages.last
    return false unless accepted_by_contact?(latest)
    return false unless latest.id > pending.fetch('requested_from_message_id').to_i

    slot_offered_after_request?(messages, latest, pending, starts_at, timezone)
  end

  def clear!
    attributes = @conversation.additional_attributes.to_h.except(PENDING_KEY)
    @conversation.update!(additional_attributes: attributes)
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

  def latest_contact_message
    public_messages.reverse.find { |message| message.incoming? && message.sender_type == 'Contact' }
  end

  def pending_confirmation
    pending = @conversation.additional_attributes.to_h[PENDING_KEY]
    return unless pending.is_a?(Hash)
    return if pending['requested_at'].blank? || Time.iso8601(pending['requested_at']) < CONFIRMATION_TTL.ago

    pending
  rescue ArgumentError
    nil
  end

  def pending_slot_matches?(pending, starts_at, duration_minutes, timezone)
    return false unless pending

    Time.iso8601(pending.fetch('starts_at')).utc == starts_at.utc &&
      pending.fetch('duration_minutes').to_i == Integer(duration_minutes) &&
      pending.fetch('timezone') == timezone &&
      pending['requested_from_message_id'].present?
  rescue ArgumentError, KeyError, TypeError
    false
  end

  def slot_offered_after_request?(messages, confirmation, pending, starts_at, timezone)
    messages.any? do |message|
      next false unless message.id > pending.fetch('requested_from_message_id').to_i && message.id < confirmation.id
      next false unless message.outgoing? && %w[Captain::Assistant AgentBot].include?(message.sender_type)

      content = normalize(message)
      includes_token?(content, date_tokens(starts_at, timezone)) &&
        includes_token?(content, time_tokens(starts_at, timezone))
    end
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
