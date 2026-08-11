class Captain::Assistant::TurnResponseQualityValidator
  EMOJI_PATTERN = /[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]/u
  SUBSTANTIVE_LENGTH = 100
  STRUCTURED_LENGTH = 180
  COMMERCIAL_STAGES = %w[greeting discovery qualification solution_fit demo_offer scheduling].freeze
  COMMERCIAL_INTENTS = %w[unknown prospect].freeze

  def initialize(response:, recent_responses: [])
    @response = response.with_indifferent_access
    @recent_responses = recent_responses
  end

  def errors
    errors = []
    content = @response['response'].to_s.strip
    errors << 'customer-facing response is blank' if content.blank?
    errors << 'customer-facing response contains more than one conversational question' if question_count > 1
    validate_commercial_quality(errors, content) if commercial_tone_stage?
    errors
  end

  private

  def validate_commercial_quality(errors, content)
    validate_emoji_quality(errors, content)
    validate_markdown_quality(errors, content)
    errors << 'response repeats a recent complete sentence' if repeated_recent_sentence?(content)
  end

  def validate_emoji_quality(errors, content)
    emoji_count = content.scan(EMOJI_PATTERN).size
    errors << 'commercial response must use one relevant emoji' if emoji_count.zero?
    errors << 'commercial response must not use more than two emojis' if emoji_count > 2
  end

  def validate_markdown_quality(errors, content)
    if content.length >= SUBSTANTIVE_LENGTH && !content.match?(/\*\*[^*\n]+\*\*/)
      errors << 'substantive commercial response must use selective Markdown bold'
    end
    return unless content.length >= STRUCTURED_LENGTH && !content.match?(/\n\n|(?:^|\n)[-*]\s/)

    errors << 'long commercial response must use paragraphs or a short list'
  end

  def commercial_tone_stage?
    COMMERCIAL_STAGES.include?(@response['commercial_stage']) &&
      COMMERCIAL_INTENTS.include?(@response['customer_intent'])
  end

  def repeated_recent_sentence?(content)
    response_sentences = normalized_sentences(content)
    return false if response_sentences.empty?

    recent_sentences = @recent_responses.flat_map { |value| normalized_sentences(value) }
    response_sentences.intersect?(recent_sentences)
  end

  def normalized_sentences(value)
    value.to_s.split(/(?<=[.!?])\s+/).filter_map do |sentence|
      normalized = ActiveSupport::Inflector.transliterate(sentence).downcase.gsub(/[^a-z0-9\s]/, ' ').squish
      normalized if normalized.length >= 50
    end
  end

  def question_count
    @question_count ||= @response['response'].to_s.count('?')
  end
end
