require 'agents'

class Captain::Tools::BasePublicTool < Agents::Tool
  def initialize(assistant)
    @assistant = assistant
    super()
  end

  def active?
    # Public tools are always active
    true
  end

  def permissions
    # Override in subclasses to specify required permissions
    # Returns empty array for public tools (no permissions required)
    []
  end

  private

  def account_scoped(model_class)
    model_class.where(account_id: @assistant.account_id)
  end

  def find_conversation(state)
    conversation_id = state&.dig(:conversation, :id)
    return nil unless conversation_id

    account_scoped(::Conversation).find_by(id: conversation_id)
  end

  def find_contact(state)
    contact_id = state&.dig(:contact, :id)
    return nil unless contact_id

    account_scoped(::Contact).find_by(id: contact_id)
  end

  def log_tool_usage(action, details = {})
    Rails.logger.info do
      "#{self.class.name}: #{action} for assistant #{@assistant&.id} - #{details.inspect}"
    end
  end

  def with_tool_audit(tool_context, request_summary: {}, idempotency_key: nil, &operation)
    execution = create_tool_execution(tool_context, request_summary, idempotency_key)
    result = ApplicationRecord.transaction(requires_new: true, &operation)
    finish_tool_execution(execution, :succeeded, result: result)
    result
  rescue Captain::Tools::RejectedExecution => e
    finish_tool_execution(execution, :rejected, error_code: e.code, result: e.message)
    e.message
  rescue StandardError => e
    finish_tool_execution(execution, :failed, error_code: e.class.name)
    raise
  end

  def reject_execution!(message, code:)
    raise Captain::Tools::RejectedExecution.new(message, code)
  end

  def create_private_audit_note(conversation, content)
    conversation.messages.create!(
      account: conversation.account,
      inbox: conversation.inbox,
      sender: @assistant,
      message_type: :outgoing,
      content: content,
      private: true
    )
  end

  def ensure_label(conversation, title, color:)
    Label.find_or_create_by!(account_id: conversation.account_id, title: title) do |label|
      label.color = color
      label.show_on_sidebar = true
    end
    conversation.update_labels(conversation.label_list | [title])
  end

  def route_and_handoff!(conversation, destination:, reason:, trusted: false, **routing)
    tool = Captain::Tools::HandoffTool.new(@assistant)
    result = if trusted
               trusted_arguments = {
                 conversation: conversation,
                 reason: reason,
                 destination: destination
               }
               trusted_arguments.merge!(routing.slice(:assignee, :team))
               tool.perform_trusted(**trusted_arguments)
             else
               tool.perform(
                 Struct.new(:state).new({ conversation: { id: conversation.id } }),
                 reason: reason,
                 destination: destination
               )
             end
    return result if result.start_with?('Conversation handed off to ')

    reject_execution!(result, code: 'handoff_rejected')
  end

  def create_tool_execution(tool_context, request_summary, idempotency_key)
    state = tool_context&.state || {}
    conversation = find_conversation(state)
    contact = conversation&.contact || find_contact(state)
    Captain::ToolExecution.create!(
      account: @assistant.account,
      assistant: @assistant,
      conversation: conversation,
      contact: contact,
      tool_name: self.class.name,
      request_summary: request_summary,
      idempotency_key: idempotency_key,
      started_at: Time.current
    )
  end

  def finish_tool_execution(execution, status, error_code: nil, result: nil)
    return unless execution

    execution.update!(
      status: status,
      error_code: error_code,
      result_summary: result.present? ? { outcome: 'returned' } : {},
      finished_at: Time.current
    )
  end
end
