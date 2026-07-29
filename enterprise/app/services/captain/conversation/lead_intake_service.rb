require 'uri'

class Captain::Conversation::LeadIntakeService
  STATE_ATTRIBUTE = 'captain_lead_intake'.freeze
  REFUSAL_PATTERN = /\b(?:nao quero|prefiro nao|nao vou|nao desejo|sem informar|recuso)\b/i

  Step = Data.define(:field, :response)

  attr_reader :awaiting_answer

  def initialize(conversation:, assistant:)
    @conversation = conversation
    @assistant = assistant
    @contact = conversation.contact
    @invalid_answer = false
    @awaiting_answer = false
  end

  def next_step
    return unless active?

    capture_expected_answer!
    return if awaiting_answer

    field = profile_status.missing_fields.first
    return clear_state! unless field

    Step.new(field: field, response: question_for(field, invalid: @invalid_answer))
  end

  def mark_question_asked!(step, message)
    attributes = @conversation.additional_attributes.to_h.merge(
      STATE_ATTRIBUTE => {
        'field' => step.field.to_s,
        'prompt_message_id' => message.id,
        'asked_at' => Time.current.iso8601
      }
    )
    @conversation.update!(additional_attributes: attributes)
  end

  private

  def active?
    return false unless @contact
    return false unless ActiveModel::Type::Boolean.new.cast(@assistant.config['feature_contact_attributes'])

    @conversation.label_list.intersect?(%w[lead_morno lead_quente])
  end

  def capture_expected_answer!
    state = intake_state
    field = expected_field(state)
    return unless field
    return clear_state! unless profile_status.missing_fields.include?(field)

    message = latest_customer_message_after(state['prompt_message_id'])
    return wait_for_answer! unless message

    capture_field!(field, message)
  rescue Captain::Conversation::ContactProfileUpdater::ValidationError => e
    @invalid_answer = true
    Rails.logger.warn(
      "[CAPTAIN][LeadIntake] rejected conversation=#{@conversation.display_id} " \
      "field=#{field} code=#{e.code}"
    )
  end

  def intake_state
    @conversation.additional_attributes.to_h[STATE_ATTRIBUTE].to_h
  end

  def expected_field(state)
    field = state['field'].to_s.to_sym
    return if field.blank? || Captain::Conversation::ContactProfileStatus::REQUIRED_FIELDS.exclude?(field)

    field
  end

  def wait_for_answer!
    @awaiting_answer = true
  end

  def capture_field!(field, message)
    value = extract_value(field, message.content_for_llm.to_s)
    return @invalid_answer = true unless value

    Captain::Conversation::ContactProfileUpdater.new(
      conversation: @conversation,
      assistant: @assistant
    ).perform(attributes: { field => value }, source: 'deterministic_lead_intake')
    clear_state!
  end

  def latest_customer_message_after(prompt_message_id)
    scope = @conversation.messages
                         .where(message_type: :incoming, private: false, sender_type: 'Contact')
                         .order(created_at: :desc, id: :desc)
    scope = scope.where('id > ?', prompt_message_id.to_i) if prompt_message_id.present?
    scope.first
  end

  def extract_value(field, content)
    normalized = content.to_s.squish
    return if normalized.blank? || refused?(normalized)

    extractor = {
      name: :extract_name,
      company_name: :extract_company,
      phone_number: :extract_phone,
      email: :extract_email
    }[field]
    method(extractor).call(normalized) if extractor
  end

  def refused?(content)
    ActiveSupport::Inflector.transliterate(content).downcase.match?(REFUSAL_PATTERN)
  end

  def extract_name(content)
    value = content.sub(
      /\A(?:meu nome (?:e|é)|eu sou|sou|pode me chamar de)\s+/i,
      ''
    ).strip
    return if value.include?('?') || value.match?(/[@\d]/)
    return unless value.match?(/\A[\p{L}][\p{L}\p{M}' -]*\z/u)
    return unless value.split.size.between?(1, 8)

    value.first(120)
  end

  def extract_company(content)
    value = content.sub(
      /\A(?:(?:o nome da )?minha empresa (?:e|é)|empresa|estabelecimento)\s*[:\-]?\s*/i,
      ''
    ).strip
    return if value.include?('?') || value.match?(URI::MailTo::EMAIL_REGEXP)
    return unless value.match?(/\p{L}/u)
    return unless value.split.size.between?(1, 20)

    value.first(160)
  end

  def extract_phone(content)
    international = content.match(/\+[1-9][\d\s().-]{7,20}/)&.to_s
    return international.squish if international

    local = content.scan(/\d/).join
    local if local.length.in?([10, 11])
  end

  def extract_email(content)
    content.match(URI::MailTo::EMAIL_REGEXP)&.to_s
  end

  def question_for(field, invalid:)
    questions = english? ? english_questions : portuguese_questions
    questions.fetch(field).fetch(invalid ? :retry : :initial)
  end

  def portuguese_questions
    {
      name: {
        initial: 'Para começarmos, qual é o seu nome?',
        retry: 'Não consegui identificar seu nome. Pode me informar seu nome completo?'
      },
      company_name: {
        initial: 'Qual é o nome da sua empresa ou estabelecimento?',
        retry: 'Não consegui identificar a empresa. Qual é o nome da sua empresa ou estabelecimento?'
      },
      phone_number: {
        initial: 'Qual é o melhor WhatsApp para continuarmos este atendimento, se necessário?',
        retry: 'Não consegui identificar o número. Pode informar seu WhatsApp com DDD?'
      },
      email: {
        initial: 'E qual é o seu melhor e-mail?',
        retry: 'Não consegui identificar um e-mail válido. Pode informar seu e-mail novamente?'
      }
    }
  end

  def english_questions
    {
      name: {
        initial: 'To get started, what is your name?',
        retry: 'I could not identify your name. What is your full name?'
      },
      company_name: {
        initial: 'What is the name of your company or establishment?',
        retry: 'I could not identify the company. What is its name?'
      },
      phone_number: {
        initial: 'What is the best WhatsApp number to continue this service conversation if needed?',
        retry: 'I could not identify the number. Please provide your WhatsApp number with area and country code.'
      },
      email: {
        initial: 'And what is your best email address?',
        retry: 'I could not identify a valid email address. Please provide it again.'
      }
    }
  end

  def english?
    @assistant.account.locale.to_s.start_with?('en')
  end

  def profile_status
    Captain::Conversation::ContactProfileStatus.new(@contact.reload)
  end

  def clear_state!
    attributes = @conversation.additional_attributes.to_h.except(STATE_ATTRIBUTE)
    @conversation.update!(additional_attributes: attributes) if attributes != @conversation.additional_attributes.to_h
    nil
  end
end
