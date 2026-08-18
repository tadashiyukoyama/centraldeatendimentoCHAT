class Api::V1::Openjarvis::MessagesController < Api::V1::Openjarvis::BaseController
  def index
    require_scope!('messages:read')
    page = cursor_page(
      conversation.messages.includes(:sender, attachments: { file_attachment: :blob }),
      type: cursor_type('conversation_messages', conversation_id: conversation.display_id),
      timestamp_column: :created_at
    )
    render json: { data: page.records.map { |message| present(message) }, meta: page.meta }
  end

  def search
    require_scope!('messages:read')
    records = filtered_messages.includes(:sender, attachments: { file_attachment: :blob })
    filters = params.permit(:q, :inbox_id, :contact_id, :conversation_id, :unread).to_h
    page = cursor_page(records, type: cursor_type('messages', filters), timestamp_column: :created_at)
    render json: { data: page.records.map { |message| present(message) }, meta: page.meta }
  end

  def create
    require_scope!('messages:write')
    validate_message_capabilities!
    execute_idempotently('messages.create', message_params.merge(conversation_id: conversation.display_id)) do
      message = Messages::MessageBuilder.new(Current.user, conversation, ActionController::Parameters.new(builder_params)).perform
      idempotent_result(status: :created, body: { data: present(message), result: operation_result(message) }, resource: message)
    end
  end

  private

  def conversation
    @conversation ||= openjarvis_access_scope.conversation!(params[:conversation_id])
  end

  def message_params
    params.require(:message).permit(
      :content, :private, :content_type, :to_emails, :cc_emails, :bcc_emails,
      :email_html_content, :reply_to_message_id, content_attributes: {}
    )
  end

  def builder_params
    values = message_params.except(:reply_to_message_id).to_h
    if message_params[:reply_to_message_id].present?
      target = conversation.messages.find_by(id: message_params[:reply_to_message_id])
      unless target
        raise Openjarvis::ApiError.new('reply_target_not_found', 'Reply target is not part of this conversation', status: :unprocessable_entity)
      end

      values['content_attributes'] = values.fetch('content_attributes', {}).merge('in_reply_to' => target.id)
    end
    values
  end

  def validate_message_capabilities!
    resolver = Openjarvis::CapabilityResolver.new(inbox: conversation.inbox)
    if message_params[:reply_to_message_id].present? && !resolver.supported?('messages.reply')
      raise Openjarvis::ApiError.new(
        'capability_not_supported',
        'Provider-native contextual reply is not supported for this inbox',
        status: :unprocessable_entity,
        details: { capability: 'messages.reply', inbox_id: conversation.inbox_id }
      )
    end
    return if message_params[:content].present?

    raise Openjarvis::ApiError.new('message_content_required', 'Message content is required', status: :bad_request)
  end

  def filtered_messages
    scope = filter_message_relations(openjarvis_access_scope.messages.joins(:conversation))
    scope = filter_unread_messages(scope)
    filter_message_content(scope)
  end

  def filter_message_relations(scope)
    scope = scope.where(inbox_id: params[:inbox_id]) if params[:inbox_id].present?
    scope = scope.where(conversations: { contact_id: params[:contact_id] }) if params[:contact_id].present?
    params[:conversation_id].present? ? scope.where(conversations: { display_id: params[:conversation_id] }) : scope
  end

  def filter_unread_messages(scope)
    return scope unless unread?

    scope.where(message_type: :incoming)
         .where('conversations.agent_last_seen_at IS NULL OR messages.created_at > conversations.agent_last_seen_at')
  end

  def filter_message_content(scope)
    return scope if params[:q].blank?

    term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.strip)}%"
    scope.where('messages.content ILIKE ?', term)
  end

  def unread?
    ActiveModel::Type::Boolean.new.cast(params[:unread])
  end

  def operation_result(message)
    {
      state: message.failed? ? 'failed' : 'accepted',
      delivery_confirmation: 'asynchronous',
      result_state: message.failed? ? 'failed' : 'unknown_until_message_updated'
    }
  end

  def present(message)
    Openjarvis::MessagePresenter.new(message).as_json
  end
end
