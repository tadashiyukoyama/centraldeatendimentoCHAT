class Captain::Conversation::GreetingPolicy
  GREETING_PATTERN = /\A(?:oi|ola|bom dia|boa tarde|boa noite|oie|e ai)[[:space:][:punct:]]*\z/i

  def initialize(conversation)
    @conversation = conversation
  end

  def greeting_only?
    latest_customer_message.present? && normalized_content(latest_customer_message).match?(GREETING_PATTERN) &&
      prior_customer_messages.none? { |message| !normalized_content(message).match?(GREETING_PATTERN) }
  end

  private

  def latest_customer_message
    public_customer_messages.last
  end

  def prior_customer_messages
    public_customer_messages[0...-1]
  end

  def public_customer_messages
    Captain::Conversation::MessageContextWindow.new(@conversation).perform.filter_map do |message|
      message if message.incoming? && message.sender_type == 'Contact'
    end
  end

  def normalized_content(message)
    ActiveSupport::Inflector.transliterate(message.content_for_llm.to_s)
                              .downcase
                              .gsub(/[^a-z0-9\s]/, ' ')
                              .squish
  end
end
