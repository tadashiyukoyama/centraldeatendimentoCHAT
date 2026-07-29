class Captain::Assistant::ProfileQuestionAppender
  MAX_QUESTION_LENGTH = 240
  LEAD_CLASSIFICATIONS = %w[lead_morno lead_quente].freeze

  def initialize(response:, context:)
    @response = response
    @state = context&.dig(:state)
  end

  def perform
    return @response unless applicable?

    question = normalized_question
    return @response unless valid_question?(question)

    question = "#{question}?" unless question.end_with?('?')
    append_unless_duplicate(question)
    @response
  end

  private

  def applicable?
    contact_profile_enabled? &&
      LEAD_CLASSIFICATIONS.include?(@response['classification']) &&
      missing_fields.include?(selected_field)
  end

  def contact_profile_enabled?
    config = @state&.dig(:assistant_config) || {}
    ActiveModel::Type::Boolean.new.cast(config['feature_contact_attributes'])
  end

  def missing_fields
    Array(@state&.dig(:contact_profile, :missing_fields)).map(&:to_s)
  end

  def selected_field
    @response['profile_question_field'].to_s
  end

  def normalized_question
    @response['profile_question'].to_s.squish
  end

  def valid_question?(question)
    question.present? && question.length <= MAX_QUESTION_LENGTH
  end

  def append_unless_duplicate(question)
    public_response = @response['response'].to_s.rstrip
    return if public_response.downcase.include?(question.downcase)

    @response['response'] = [public_response, question].compact_blank.join("\n\n")
  end
end
