class Captain::Conversation::PaymentNoticeEvidence
  NOTICE_PATTERNS = [
    /\b(?:paguei|quitei)\b/i,
    /\b(?:fiz|efetuei|realizei)\s+(?:o\s+)?(?:pagamento|pix|transferencia|deposito)\b/i,
    /\b(?:pagamento|pix|transferencia|deposito)\s+(?:foi\s+)?(?:feito|realizado|efetuado|enviado)\b/i,
    /\b(?:enviei|mandei|anexei|segue)\s+(?:o\s+)?comprovante\b/i
  ].freeze
  AMOUNT_PATTERNS = [
    /r\$\s*(\d(?:[\d.,]*\d)?)/i,
    /\b(?:valor|total|paguei|pagamento|pix|transferencia|deposito)\s+(?:de\s+)?(\d(?:[\d.,]*\d)?)/i
  ].freeze

  def initialize(conversation)
    @conversation = conversation
  end

  def present?
    NOTICE_PATTERNS.any? { |pattern| normalized_content.match?(pattern) }
  end

  def amount_explicit?(amount)
    expected_cents = Captain::PaymentAmount.to_cents(amount)
    extracted_amounts.any? { |candidate| Captain::PaymentAmount.to_cents(candidate) == expected_cents }
  rescue Captain::PaymentAmount::InvalidAmount
    false
  end

  def reference_explicit?(reference)
    value = normalize_reference(reference)
    value.length >= 3 && normalize_reference(latest_content).include?(value)
  end

  def currency_explicit?(currency)
    code = currency.to_s.upcase
    return true if code == 'BRL'

    normalized_content.match?(/\b#{Regexp.escape(code.downcase)}\b/)
  end

  private

  def latest_message
    message = Captain::Conversation::MessageContextWindow.new(@conversation).perform.reject(&:activity?).last
    return message if message&.incoming? && message.sender_type == 'Contact'
  end

  def latest_content
    latest_message&.content_for_llm.to_s
  end

  def normalized_content
    ActiveSupport::Inflector.transliterate(latest_content).downcase
  end

  def extracted_amounts
    AMOUNT_PATTERNS.flat_map { |pattern| normalized_content.scan(pattern).flatten }.compact
  end

  def normalize_reference(value)
    ActiveSupport::Inflector.transliterate(value.to_s).downcase.gsub(/[^a-z0-9]/, '')
  end
end
