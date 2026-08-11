class Captain::Assistant::TurnContractValidator
  PROFILE_FIELDS = Captain::Conversation::CommercialTurnPolicy::PROFILE_FIELDS
  REQUIRED_FIELDS = %w[
    response
    reasoning
    classification
    customer_intent
    commercial_stage
    immediate_objective
    captured_profile_fields
    requested_profile_fields
    declined_profile_fields
    knowledge_grounded
  ].freeze
  PRODUCT_CLAIM_PATTERN = /
    \b(?:centraliz(?:a|ado|ar)|re[uú]ne|permite|oferece|possui|integra|automatiza|funciona|inclui|
    reduz|organiza|acompanha|gerencia|envia|conecta)\b
  /ix

  def initialize(response:, run_result:, policy:, recent_responses: [])
    @response = response.with_indifferent_access
    @run_result = run_result
    @policy = policy.with_indifferent_access
    @recent_responses = recent_responses
  end

  def errors
    return @errors if defined?(@errors)

    @errors = []
    validate_required_fields(@errors)
    validate_contract_fields unless @errors.any?
    @errors.uniq!
    @errors
  end

  private

  def validate_required_fields(errors)
    missing = REQUIRED_FIELDS.reject { |field| @response.key?(field) && !@response[field].nil? }
    errors << "missing structured fields: #{missing.join(', ')}" if missing.any?
  end

  def validate_profile_contract(errors)
    captured = profile_fields('captured_profile_fields', errors)
    requested = profile_fields('requested_profile_fields', errors)
    declined = profile_fields('declined_profile_fields', errors)

    validate_due_profile_fields(errors, captured, requested, declined)
    validate_profile_reply(errors, captured, declined)
    validate_declined_profile_fields(errors, declined)
    validate_profile_question(errors, requested)
    validate_profile_persistence(errors, captured)
  end

  def validate_profile_reply(errors, captured, declined)
    return unless @policy['likely_profile_reply']

    expected = Array(@policy['previous_requested_profile_fields']) & PROFILE_FIELDS
    return if expected.intersect?(captured | declined)

    errors << 'likely profile reply requires capture_contact_profile or an explicit refusal'
  end

  def validate_declined_profile_fields(errors, declined)
    return if declined.empty?

    unless @policy['latest_message_has_profile_refusal']
      errors << 'declined profile fields require an explicit refusal in the latest customer message'
      return
    end

    allowed = Array(@policy['declinable_profile_fields']) & PROFILE_FIELDS
    unsupported = declined - allowed
    return if unsupported.empty?

    errors << "declined profile fields are not supported by the latest refusal: #{unsupported.join(', ')}"
  end

  def validate_due_profile_fields(errors, captured, requested, declined)
    return unless @response['customer_intent'] == 'prospect'

    required = Array(@policy['required_profile_fields_if_prospect']) & PROFILE_FIELDS
    outstanding = required - captured - requested - declined
    errors << "profile fields due in this turn were neither captured nor requested: #{outstanding.join(', ')}" if outstanding.any?
  end

  def validate_profile_question(errors, requested)
    errors << 'requested profile fields are not represented by a customer-facing question' if requested.any? && question_count.zero?
  end

  def validate_profile_persistence(errors, captured)
    persisted = captured_profile_fields_from_tools
    unpersisted = captured - persisted
    errors << "profile fields were reported as captured without a successful tool result: #{unpersisted.join(', ')}" if unpersisted.any?

    machine_detected = Array(@policy['machine_detected_profile_fields']) & PROFILE_FIELDS
    missing_tool_capture = machine_detected - persisted
    errors << "explicit profile fields require capture_contact_profile: #{missing_tool_capture.join(', ')}" if missing_tool_capture.any?
  end

  def validate_contract_fields
    validate_intent_consistency(@errors)
    validate_profile_contract(@errors)
    validate_classification_tool(@errors)
    validate_knowledge_grounding(@errors)
    validate_response_quality(@errors)
  end

  def validate_intent_consistency(errors)
    return if @policy['greeting_only'] && @response['customer_intent'] == 'unknown'

    expected_intent = @response['classification'] == 'cliente' ? 'customer' : 'prospect'
    return if @response['customer_intent'] == expected_intent

    errors << "customer_intent must be #{expected_intent} for classification #{@response['classification']}"
  end

  def profile_fields(key, errors)
    fields = Array(@response[key]).map(&:to_s)
    invalid = fields - PROFILE_FIELDS
    errors << "invalid #{key}: #{invalid.join(', ')}" if invalid.any?
    fields & PROFILE_FIELDS
  end

  def validate_classification_tool(errors)
    target = @response['classification'].to_s
    initial_labels = Array(@policy['initial_classification_labels'])
    return if initial_labels.include?(target)
    return if tool_results.any? { |entry| classify_tool?(entry['name']) && entry['result'].to_s.include?("'#{target}'") }

    errors << "classification change to #{target} requires classify_lead"
  end

  def validate_knowledge_grounding(errors)
    grounded = @response['knowledge_grounded'] == true
    errors << 'factual product claims must be marked as knowledge-grounded' if factual_product_claim? && !grounded
    errors << 'knowledge_grounded requires FAQ lookup with approved sources in this run' if grounded && !approved_faq_used?
  end

  def validate_response_quality(errors)
    errors.concat(
      Captain::Assistant::TurnResponseQualityValidator.new(
        response: @response,
        recent_responses: @recent_responses
      ).errors
    )
  end

  def factual_product_claim?
    @response['response'].to_s.match?(PRODUCT_CLAIM_PATTERN) || @response['commercial_stage'] == 'solution_fit'
  end

  def approved_faq_used?
    tool_results.any? { |entry| faq_tool?(entry['name']) } && retrieved_faq_ids.any?
  end

  def question_count
    @question_count ||= @response['response'].to_s.count('?')
  end

  def captured_profile_fields_from_tools
    tool_results.filter_map do |entry|
      next unless capture_profile_tool?(entry['name'])

      result = JSON.parse(entry['result'].to_s)
      Array(result['saved_fields']) if result['status'] == 'saved'
    rescue JSON::ParserError
      nil
    end.flatten.uniq & PROFILE_FIELDS
  end

  def retrieved_faq_ids
    state = @run_result&.context&.dig(:state) || {}
    Array(state.dig(:cw_metadata, :faq_ids) || state.dig('cw_metadata', 'faq_ids'))
  end

  def tool_results
    context = @run_result&.context || {}
    @tool_results ||= Array(context[:captain_v2_tool_results] || context['captain_v2_tool_results']).map(&:with_indifferent_access)
  end

  def capture_profile_tool?(name)
    name.to_s.end_with?('capture_contact_profile')
  end

  def classify_tool?(name)
    name.to_s.end_with?('classify_lead')
  end

  def faq_tool?(name)
    name.to_s.end_with?('faq_lookup')
  end
end
