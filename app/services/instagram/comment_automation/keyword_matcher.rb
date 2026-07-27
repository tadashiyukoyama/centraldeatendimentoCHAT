class Instagram::CommentAutomation::KeywordMatcher
  Match = Data.define(:automation, :keyword)

  def initialize(inbox:, text:, media_id:, nested_reply:, occurred_at: Time.current)
    @inbox = inbox
    @text = text.to_s
    @media_id = media_id.to_s
    @nested_reply = nested_reply
    @occurred_at = occurred_at
  end

  def call
    candidates.each do |automation|
      keyword = matching_keyword(automation)
      return Match.new(automation: automation, keyword: keyword) if keyword
    end

    nil
  end

  private

  def candidates
    scope = @inbox.instagram_comment_automations.enabled.in_precedence_order
    scope = scope.where(media_id: [nil, '', @media_id])
    scope.where('starts_at IS NULL OR starts_at <= ?', @occurred_at)
         .where('ends_at IS NULL OR ends_at >= ?', @occurred_at)
  end

  def matching_keyword(automation)
    return if @nested_reply && !automation.include_nested_replies?

    normalized_text = normalize(@text)
    automation.keywords.find do |keyword|
      normalized_keyword = normalize(keyword)
      matches?(automation.match_type, normalized_text, normalized_keyword)
    end
  end

  def matches?(match_type, text, keyword)
    return false if keyword.blank?

    case match_type
    when 'exact'
      text == keyword
    when 'contains'
      text.include?(keyword)
    else
      " #{text} ".include?(" #{keyword} ")
    end
  end

  def normalize(value)
    I18n.transliterate(value.to_s.unicode_normalize(:nfkc))
        .downcase
        .gsub(/[^\p{Alnum}_]+/u, ' ')
        .squish
  end
end
