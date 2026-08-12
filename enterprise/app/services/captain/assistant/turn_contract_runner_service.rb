class Captain::Assistant::TurnContractRunnerService
  MAX_ATTEMPTS = 3
  READ_ONLY_TOOL_SUFFIXES = %w[faq_lookup lookup_payment_status].freeze
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
    context[:state][:commercial_retry] = {
      previous_response: response.except('reasoning'),
      completed_tool_results: tool_results(previous_context),
      tools_locked: mutating_tool_used?(run_result)
    }
    context
  end

  def carry_knowledge_metadata!(context, previous_context)
    metadata = previous_context.dig(:state, :cw_metadata) || previous_context.dig('state', 'cw_metadata')
    context[:state][:cw_metadata] = metadata.deep_dup if metadata.present?
  end

  def mutating_tool_used?(run_result)
    tool_results(run_result&.context).any? do |entry|
      name = (entry[:name] || entry['name']).to_s
      READ_ONLY_TOOL_SUFFIXES.none? { |suffix| name.end_with?(suffix) }
    end
  end

  def runner_for(attempt, context)
    return @runner if attempt.zero? || !context.dig(:state, :commercial_retry, :tools_locked)

    @repair_runner_provider.call
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
