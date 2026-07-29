class Captain::Conversation::ContactProfileEvidence
  def initialize(conversation)
    @conversation = conversation
  end

  def explicit?(field, value)
    message_for(field, value).present?
  end

  def message_for(field, value)
    normalized_value = normalize(field, value)
    return if normalized_value.blank?

    incoming_messages.find do |message|
      normalized_content = normalize(field, message.content_for_llm)
      if field.to_sym == :phone_number
        phone_matches?(normalized_content, normalized_value)
      else
        normalized_content.include?(normalized_value)
      end
    end
  end

  private

  def incoming_messages
    Captain::Conversation::MessageContextWindow.new(@conversation)
                                               .perform
                                               .select(&:incoming?)
                                               .select { |message| message.sender_type == 'Contact' }
                                               .last(20)
  end

  def normalize(field, value)
    return value.to_s.gsub(/\D/, '') if field.to_sym == :phone_number
    return value.to_s.strip.downcase if field.to_sym == :email

    ActiveSupport::Inflector.transliterate(value.to_s)
                            .downcase
                            .gsub(/[^\p{Alnum}\s]/, ' ')
                            .squish
  end

  def phone_matches?(content_digits, value_digits)
    return true if content_digits.include?(value_digits)
    return false if value_digits.length < 10

    local_digits = value_digits.last([11, value_digits.length].min)
    content_digits.include?(local_digits)
  end
end
