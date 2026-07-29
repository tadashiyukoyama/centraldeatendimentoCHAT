class Captain::Conversation::ResponseBuilderJob < ApplicationJob
  include Captain::Conversation::V1ActionClassifier
  include Captain::Conversation::V1FalsePromiseHandler
  include Captain::Conversation::MessageBuilder

  MAX_MESSAGE_LENGTH = 10_000
  retry_on ActiveStorage::FileNotFoundError, attempts: 3, wait: 2.seconds
  retry_on Faraday::BadRequestError, attempts: 3, wait: 2.seconds

  def perform(conversation, assistant)
    @conversation = conversation
    @inbox = conversation.inbox
    @assistant = assistant

    return unless conversation_pending?

    Captain::Conversation::OriginResolver.new(conversation).perform
    Current.executed_by = @assistant

    if captain_v2_enabled?
      generate_response_with_v2
    else
      generate_and_process_response
    end
  rescue ActiveStorage::FileNotFoundError, Faraday::BadRequestError => e
    handle_error(e)
    raise e
  rescue StandardError => e
    handle_error(e)
  ensure
    Current.executed_by = nil
  end

  private

  delegate :account, :inbox, to: :@conversation

  def generate_and_process_response
    message_history = collect_previous_messages
    @response = Captain::Llm::AssistantChatService.new(assistant: @assistant, conversation: @conversation).generate_response(
      message_history: message_history
    )
    classify_v1_response_action(message_history) if conversation_pending?
    repair_v1_false_promise_response(message_history) if conversation_pending?
    apply_lead_classification
    process_response
  end

  def generate_response_with_v2
    runner_service = Captain::Assistant::AgentRunnerService.new(assistant: @assistant, conversation: @conversation)
    message_history = Captain::Conversation::MessageHistoryBuilderService.new(conversation: @conversation).perform
    @response = runner_service.generate_response(message_history: message_history)
    @run_result = runner_service.last_run_result

    apply_lead_classification
    process_response
  end

  def apply_lead_classification
    Captain::Conversation::LeadClassificationService.new(conversation: @conversation).perform(
      classification: @response['classification']
    )
  end

  def process_response
    # Provider errors are internal failures, not customer-visible handoff requests.
    return process_generation_error if generation_error_response?
    return process_handoff_response if v2_handoff_tool_fired?
    return process_v1_handoff if v1_handoff_requested? && conversation_pending?

    process_standard_response if conversation_pending?
  end

  def process_handoff_response
    if conversation_pending?
      # A successful V2 handoff always opens the conversation before the SDK returns.
      # If that invariant is broken, fail closed: route to a human and record a private
      # diagnostic, but never fabricate or rewrite a customer-facing response.
      process_inconsistent_v2_handoff
    else
      # HandoffTool already changed operational state. The SDK then returned to the
      # model for the final customer-facing response, which is delivered verbatim.
      process_v2_handoff
    end
    capture_assistant_session(result_message: @handoff_message, credits_consumed: 0.0)
  end

  def process_standard_response
    message = nil
    ActiveRecord::Base.transaction do
      message = create_messages
      Rails.logger.info("[CAPTAIN][ResponseBuilderJob] Incrementing response usage for #{account.id}")
      account.increment_response_usage
    end
    capture_assistant_session(result_message: message, credits_consumed: 1.0)
  end

  def v1_handoff_requested?
    legacy_v1_handoff_token? || classifier_v1_handoff_requested?
  end

  def generation_error_response?
    @response&.dig('error') == true || @response&.dig('action_source') == 'error' || @response&.dig('response').blank?
  end

  def classifier_v1_handoff_requested?
    @response['action'] == 'handoff'
  end

  def legacy_v1_handoff_token?
    @response['response'] == 'conversation_handoff'
  end

  def v2_handoff_tool_fired?
    @response['handoff_tool_called']
  end

  def process_v1_handoff
    I18n.with_locale(@assistant.account.locale) do
      Rails.logger.info(
        "[CAPTAIN][ResponseBuilderJob] V1 handoff requested for account=#{account.id} conversation=#{@conversation.display_id} " \
        "source=#{@response&.dig('action_source') || 'legacy'} reason=#{@response&.dig('action_reason')}"
      )
      create_handoff_message
      @conversation.bot_handoff!
      report_v1_handoff_not_executed if conversation_pending?
      send_out_of_office_message_if_applicable
    end
  end

  def process_v2_handoff
    # Preserve waiting_since so the exact agent reply does not clear the timestamp
    # left by HandoffTool for human reply-time tracking.
    @handoff_message = create_messages(preserve_waiting_since: true)
  end

  def process_inconsistent_v2_handoff
    create_outgoing_message(
      'Nemmo reported a completed handoff, but the conversation remained pending. Human follow-up is required.',
      private_note: true
    )
    @conversation.bot_handoff!
    send_out_of_office_message_if_applicable
    @handoff_message = nil
  end

  def send_out_of_office_message_if_applicable
    # Campaign conversations should never receive OOO templates — the campaign itself
    # serves as the initial outreach, and OOO would be confusing in that context.
    return if @conversation.campaign.present?

    ::MessageTemplates::Template::OutOfOffice.perform_if_applicable(@conversation)
  end

  def create_handoff_message
    @handoff_message = create_outgoing_message(
      Captain::Conversation::HandoffMessageResolver.new(
        conversation: @conversation,
        assistant: @assistant
      ).perform
    )
  end

  # Capture runs outside the delivery transaction and never raises (the service
  # swallows its own failures): a session-logging bug must never roll back the
  # customer reply or trigger the top-level handle_error handoff on top of it.
  def capture_assistant_session(result_message:, credits_consumed:)
    Captain::Assistant::SessionCaptureService.new(assistant: @assistant, conversation: @conversation, run_result: @run_result,
                                                  result_message: result_message, credits_consumed: credits_consumed).capture
  end

  def handle_error(error)
    log_error(error)
    @response ||= {}
    @response['action_source'] ||= 'error'
    @response['action_reason'] ||= error_action_reason(error)
    if captain_v2_enabled?
      process_generation_error
    elsif conversation_pending?
      process_v1_handoff
    end
    true
  end

  def process_generation_error
    create_outgoing_message(
      'Nemmo could not generate a response automatically. Human follow-up is required.',
      private_note: true
    )
    @conversation.bot_handoff! if conversation_pending?
  rescue StandardError => e
    # Do not hide the original provider failure or create a second public message.
    Rails.logger.error(
      '[CAPTAIN][ResponseBuilderJob] Failed to record generation error handoff for ' \
      "account=#{account.id} conversation=#{@conversation.display_id}: #{e.message}"
    )
  end

  def log_error(error)
    ChatwootExceptionTracker.new(error, account: account).capture_exception
  end

  def error_action_reason(error)
    error.class.name.underscore.tr('/', '_')
  end

  def captain_v2_enabled?
    account.feature_enabled?('captain_integration_v2')
  end

  def report_v1_handoff_not_executed
    error = StandardError.new("Captain V1 handoff requested but conversation #{@conversation.display_id} is still pending")
    ChatwootExceptionTracker.new(error, account: account).capture_exception
    Rails.logger.error(
      "[CAPTAIN][ResponseBuilderJob] V1 handoff requested but not executed for account=#{account.id} " \
      "conversation=#{@conversation.display_id}"
    )
  end

  def conversation_pending?
    status = Conversation.uncached { Conversation.where(id: @conversation.id).pick(:status) }
    status == 'pending' || status == Conversation.statuses[:pending]
  end
end
