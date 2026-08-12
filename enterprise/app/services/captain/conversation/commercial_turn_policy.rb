class Captain::Conversation::CommercialTurnPolicy
  PROFILE_FIELDS = %w[name company_name phone_number email].freeze
  IDENTITY_FIELDS = %w[name company_name].freeze
  CONTACT_FIELDS = %w[phone_number email].freeze
  PROFILE_REPLY_MAX_WORDS = 30
  MACHINE_FIELD_PATTERNS = {
    'email' => /[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}/i,
    'phone_number' => /(?:\+?\d[\d\s().-]{7,}\d)/
  }.freeze
  PROFILE_REFUSAL_PATTERN = /
    \b(?:n[aã]o\s+(?:quero|vou|posso|desejo)\s+(?:informar|passar|compartilhar)|prefiro\s+n[aã]o|
    do\s+not\s+want\s+to\s+share|prefer\s+not\s+to)\b
  /ix
  ACKNOWLEDGEMENT_PATTERN = /\A(?:sim|n[aã]o|ok|obrigad[oa]|entendi|claro|beleza|pode\s+ser)[.!\s]*\z/i
  NON_PROFILE_INTENT_PATTERN = /\A(?:como|quanto|quais?|por\s+que|o\s+que|voc[eê]|quero|preciso|gostaria)\b/i
  DECLINED_FIELD_PATTERNS = {
    'name' => /\bnome\b/i,
    'company_name' => /\b(?:empresa|estabelecimento|restaurante|neg[oó]cio)\b/i,
    'phone_number' => /\b(?:telefone|whats(?:app)?|celular)\b/i,
    'email' => /\be-?mail\b/i
  }.freeze

  def initialize(conversation:)
    @conversation = conversation
  end

  def perform
    {
      enabled: true,
      greeting_only: greeting_only?,
      customer_turn_count: customer_messages.size,
      initial_classification_labels: @conversation.label_list & Captain::ResponseSchema::CLASSIFICATIONS,
      channel_type: @conversation.inbox&.channel_type,
      response_contract: response_contract
    }.merge(profile_contract)
  end

  private

  def profile_contract
    {
      missing_profile_fields: missing_profile_fields,
      required_profile_fields_if_prospect: required_profile_fields,
      previous_requested_profile_fields: previous_requested_profile_fields,
      declined_profile_fields: declined_profile_fields,
      machine_detected_profile_fields: machine_detected_profile_fields,
      likely_profile_reply: likely_profile_reply?,
      latest_message_has_profile_refusal: latest_message_has_profile_refusal?,
      declinable_profile_fields: declinable_profile_fields
    }
  end

  def response_contract
    {
      one_question_maximum: true,
      markdown_for_substantive_replies: true,
      relevant_emoji_range: '1-2',
      repeat_recent_sentences: false
    }
  end

  def greeting_only?
    Captain::Conversation::GreetingPolicy.new(@conversation).greeting_only?
  end

  def customer_messages
    @customer_messages ||= context_messages.select do |message|
      message.incoming? && message.sender_type == 'Contact'
    end
  end

  def context_messages
    @context_messages ||= Captain::Conversation::MessageContextWindow.new(@conversation).perform
  end

  def missing_profile_fields
    status = Captain::Conversation::ContactProfileStatus.new(@conversation.contact)
    @missing_profile_fields ||= status.missing_fields.map(&:to_s)
  end

  def required_profile_fields
    return [] if greeting_only?

    available_missing_fields = missing_profile_fields - declined_profile_fields
    identity_fields = available_missing_fields & IDENTITY_FIELDS
    return suppress_immediate_repeat(identity_fields) if identity_fields.any?
    return [] if customer_messages.size < 2

    suppress_immediate_repeat(available_missing_fields & CONTACT_FIELDS)
  end

  def suppress_immediate_repeat(fields)
    return fields unless fields.intersect?(previous_requested_profile_fields)

    []
  end

  def previous_requested_profile_fields
    Array(previous_contract['requested_profile_fields']) & PROFILE_FIELDS
  end

  def declined_profile_fields
    recent_contracts.flat_map { |contract| Array(contract['declined_profile_fields']) }.uniq & PROFILE_FIELDS
  end

  def previous_contract
    recent_contracts.last || {}
  end

  def recent_contracts
    @recent_contracts ||= recent_sessions.filter_map { |session| latest_contract(session.run_context) }
  end

  def latest_contract(run_context)
    Array(run_context).reverse_each do |message|
      content = message['content']
      return content if message['role'].to_s == 'assistant' && content.is_a?(Hash) && content.key?('commercial_stage')
    end
    nil
  end

  def recent_sessions
    scope = Captain::AgentSession.where(subject: @conversation).order(created_at: :asc, id: :asc)
    first_context_message = context_messages.first
    scope = scope.where(created_at: first_context_message.created_at..) if first_context_message
    scope.last(10)
  end

  def machine_detected_profile_fields
    MACHINE_FIELD_PATTERNS.filter_map { |field, pattern| field if latest_customer_content.match?(pattern) }
                          .select { |field| missing_profile_fields.include?(field) }
  end

  def likely_profile_reply?
    return false if previous_requested_profile_fields.empty?
    return false if latest_customer_content.blank? || latest_customer_content.include?('?')
    return false if latest_customer_content.match?(ACKNOWLEDGEMENT_PATTERN)
    return false if latest_customer_content.match?(NON_PROFILE_INTENT_PATTERN)

    latest_customer_content.split.size <= PROFILE_REPLY_MAX_WORDS
  end

  def latest_message_has_profile_refusal?
    latest_customer_content.match?(PROFILE_REFUSAL_PATTERN)
  end

  def declinable_profile_fields
    return [] unless latest_message_has_profile_refusal?

    explicit_fields = DECLINED_FIELD_PATTERNS.filter_map do |field, pattern|
      field if latest_customer_content.match?(pattern)
    end
    explicit_fields.presence || previous_requested_profile_fields
  end

  def latest_customer_content
    @latest_customer_content ||= customer_messages.last&.content_for_llm.to_s.squish
  end
end
