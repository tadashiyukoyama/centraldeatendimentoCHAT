class Captain::Assistant::TurnResponsePresentationService
  EMOJI_PATTERN = Captain::Assistant::TurnResponseQualityValidator::EMOJI_PATTERN
  COMMERCIAL_EMOJI_BY_STAGE = {
    'greeting' => '👋',
    'discovery' => '💬',
    'qualification' => '💬',
    'solution_fit' => '✨',
    'demo_offer' => '✨',
    'scheduling' => '📅'
  }.freeze

  pattr_initialize [:response!]

  def perform
    presented = response.with_indifferent_access.deep_dup
    content = presented['response'].to_s.strip
    return presented if content.blank? || content.match?(EMOJI_PATTERN)

    emoji = COMMERCIAL_EMOJI_BY_STAGE[presented['commercial_stage'].to_s]
    return presented if emoji.blank? || %w[unknown prospect].exclude?(presented['customer_intent'].to_s)

    presented['response'] = "#{content} #{emoji}"
    presented
  end
end
