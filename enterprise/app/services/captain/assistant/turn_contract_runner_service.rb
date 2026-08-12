class Captain::Assistant::TurnContractRunnerService
  MAX_ATTEMPTS = 3
  READ_ONLY_TOOL_SUFFIXES = %w[faq_lookup lookup_payment_status].freeze
  REPAIRABLE_MUTATING_TOOLS = {
    'classify_lead' => /requires classify_lead/,
    'capture_contact_profile' => /(?:explicit profile fields require capture_contact_profile|likely profile reply requires capture_contact_profile)/
  }.freeze
  Result = Data.define(:response, :run_result)

  def initialize(assistant:, conversation:, runner:, repair_runner_provider:, runtime:)
    @assistant = assistant
    @conversation = conversation
    @runner = runner
    @repair_runner_provider = repair_runner_provider
    @payload_builder = runtime.fetch(:payload_builder)
    @result_processor = runtime.fetch(:result_processor)
  end

  def perform(message_history:)
    message_to_process, context = @payload_builder.call(message_history)
    validation_errors = []

    MAX_ATTEMPTS.times do |attempt|
      active_runner = runner_for(attempt, context)
      run_result = active_runner.run(message_to_process, context: context, max_turns: 10)
      response = @result_processor.call(run_result)
      response = reconcile_tool_evidence(response, run_result)
      response = Captain::Assistant::TurnResponsePresentationService.new(response: response).perform
      validation_errors = validate(response, run_result, message_history)
      return Result.new(response: response, run_result: run_result) if validation_errors.empty? || response['handoff_tool_called']

      log_rejection(attempt + 1, validation_errors)
      context = retry_context(message_history, validation_errors, response, run_result) if retry?(attempt)
    end

    raise "Agent SDK commercial turn contract failed: #{validation_errors.join('; ')}"
  end

  private

  def validate(response, run_result, message_history)
    policy = run_result.context&.dig(:state, :commercial_turn) || {}
    Captain::Assistant::TurnContractValidator.new(
      response: response,
      run_result: run_result,
      policy: policy,
      recent_responses: recent_assistant_responses(message_history)
    ).errors
  end

  def reconcile_tool_evidence(response, run_result)
    response = response.with_indifferent_access
    results = tool_results(run_result&.context)
    captured_fields = reconcile_profile_evidence!(response, results)
    refresh_commercial_policy!(run_result) if captured_fields.any?
    reconcile_classification_evidence!(response, results)
    response['knowledge_grounded'] = approved_faq_evidence?(results, run_result)
    response
  end

  def reconcile_profile_evidence!(response, results)
    captured_fields = results.flat_map { |entry| saved_profile_fields(entry) }.uniq
    response['captured_profile_fields'] = (Array(response['captured_profile_fields']).map(&:to_s) + captured_fields).uniq
    captured_fields
  end

  def refresh_commercial_policy!(run_result)
    return unless @conversation && run_result&.context

    refresh_conversation_state!
    state = run_result.context[:state] || run_result.context['state'] || {}
    state[:commercial_turn] = Captain::Conversation::CommercialTurnPolicy.new(conversation: @conversation).perform
  end

  def reconcile_classification_evidence!(response, results)
    classification = results.filter_map { |entry| classified_lead(entry) }.last
    return unless classification

    response['classification'] = classification
    response['customer_intent'] = classification == 'cliente' ? 'customer' : 'prospect'
  end

  def saved_profile_fields(entry)
    return [] unless tool_name(entry).end_with?('capture_contact_profile')

    result = JSON.parse((entry[:result] || entry['result']).to_s)
    return [] unless result['status'] == 'saved'

    Array(result['saved_fields']).map(&:to_s) & Captain::Conversation::CommercialTurnPolicy::PROFILE_FIELDS
  rescue JSON::ParserError
    []
  end

  def classified_lead(entry)
    return unless tool_name(entry).end_with?('classify_lead')

    (entry[:result] || entry['result']).to_s[/classified as '(cliente|lead_morno|lead_quente)'/, 1]
  end

  def approved_faq_evidence?(results, run_result)
    return false unless results.any? { |entry| tool_name(entry).end_with?('faq_lookup') }

    metadata = knowledge_metadata(run_result)
    faq_ids = metadata[:faq_ids] || metadata['faq_ids']
    Array(faq_ids).any?
  end

  def knowledge_metadata(run_result)
    context = run_result&.context || {}
    state = context[:state] || context['state'] || {}
    state[:cw_metadata] || state['cw_metadata'] || {}
  end

  def tool_name(entry)
    (entry[:name] || entry['name']).to_s
  end

  def recent_assistant_responses(message_history)
    message_history.filter_map do |message|
      next unless (message[:role] || message['role']).to_s == 'assistant'

      extract_response(message[:content] || message['content'])
    end.last(6)
  end

  def extract_response(content)
    return content[:response] || content['response'] || content.to_s if content.is_a?(Hash)

    content.to_s
  end

  def retry_context(message_history, validation_errors, response, run_result)
    refresh_conversation_state!
    _message_to_process, context = @payload_builder.call(message_history)
    previous_context = run_result.context || {}
    context[:captain_v2_tool_results] = tool_results(previous_context)
    carry_knowledge_metadata!(context, previous_context)
    context[:state][:commercial_validation_feedback] = validation_errors
    available_tools = available_repair_tools(validation_errors, previous_context)
    context[:state][:commercial_retry] = {
      previous_response: response.except('reasoning'),
      completed_tool_results: tool_results(previous_context),
      restricted_tools: mutating_tool_used?(run_result),
      available_tools: available_tools,
      tools_locked: mutating_tool_used?(run_result) && available_tools.empty?
    }
    context
  end

  def carry_knowledge_metadata!(context, previous_context)
    metadata = previous_context.dig(:state, :cw_metadata) || previous_context.dig('state', 'cw_metadata')
    context[:state][:cw_metadata] = metadata.deep_dup if metadata.present?
  end

  def mutating_tool_used?(run_result)
    tool_results(run_result&.context).any? do |entry|
      name = tool_name(entry)
      READ_ONLY_TOOL_SUFFIXES.none? { |suffix| name.end_with?(suffix) }
    end
  end

  def runner_for(attempt, context)
    retry_state = context.dig(:state, :commercial_retry) || {}
    return @runner if attempt.zero? || !retry_state[:restricted_tools]

    @repair_runner_provider.call(Array(retry_state[:available_tools]))
  end

  def available_repair_tools(validation_errors, context)
    completed_names = tool_results(context).map { |entry| tool_name(entry) }

    REPAIRABLE_MUTATING_TOOLS.filter_map do |tool_id, error_pattern|
      next unless validation_errors.any? { |error| error.match?(error_pattern) }
      next if completed_names.any? { |name| name.end_with?(tool_id) }

      tool_id
    end
  end

  def tool_results(context)
    context ||= {}
    Array(context[:captain_v2_tool_results] || context['captain_v2_tool_results'])
  end

  def refresh_conversation_state!
    return unless @conversation

    @conversation.reload
    @conversation.association(:contact).reset
    @conversation.association(:inbox).reset
  end

  def retry?(attempt)
    attempt + 1 < MAX_ATTEMPTS
  end

  def log_rejection(attempt, errors)
    Rails.logger.warn(
      '[Captain V2] Commercial turn rejected ' \
      "assistant=#{@assistant.id} conversation=#{@conversation&.display_id} attempt=#{attempt} errors=#{errors.join(' | ')}"
    )
  end
end
