class Api::V1::Openjarvis::ConversationsController < Api::V1::Openjarvis::BaseController
  def index
    require_scope!('conversations:read')
    records = filtered_conversations
    page = cursor_page(
      records.includes(:inbox, :contact, :assignee, :team),
      type: cursor_type('conversations', params.permit(:inbox_id, :contact_id, :status, :updated_after).to_h)
    )
    render json: { data: page.records.map { |conversation| present(conversation) }, meta: page.meta }
  end

  def show
    require_scope!('conversations:read')
    render json: { data: present(conversation) }
  end

  def create
    require_scope!('conversations:write')
    validate_create_params!
    execute_idempotently('conversations.create', create_params) do
      create_conversation_result
    end
  end

  def update
    require_scope!('conversations:write')
    validate_update_params!
    execute_idempotently('conversations.update', update_params.merge(id: conversation.display_id)) do
      apply_conversation_updates
      idempotent_result(status: :ok, body: { data: present(conversation.reload) }, resource: conversation)
    end
  end

  def mark_read
    require_scope!('conversations:write')
    execute_idempotently('conversations.mark_read', { id: conversation.display_id }) do
      seen_at = [conversation.messages.incoming.maximum(:created_at), Time.current].compact.max
      conversation.update!(agent_last_seen_at: seen_at)
      idempotent_result(
        status: :ok,
        body: { data: { conversation_id: conversation.display_id, read_at: seen_at.iso8601, provider_receipt_sent: false } },
        resource: conversation
      )
    end
  end

  private

  def conversation
    @conversation ||= openjarvis_access_scope.conversation!(params[:id])
  end

  def filtered_conversations
    scope = filter_conversation_ids(openjarvis_access_scope.conversations)
    scope = filter_conversation_status(scope)
    filter_conversation_updated_at(scope)
  end

  def filter_conversation_ids(scope)
    scope = scope.where(inbox_id: params[:inbox_id]) if params[:inbox_id].present?
    params[:contact_id].present? ? scope.where(contact_id: params[:contact_id]) : scope
  end

  def filter_conversation_status(scope)
    return scope if params[:status].blank?

    validate_enum_value!(Conversation, :status, params[:status])
    scope.where(status: params[:status])
  end

  def filter_conversation_updated_at(scope)
    return scope if params[:updated_after].blank?

    scope.where('conversations.updated_at >= ?', parse_iso8601!(params[:updated_after], parameter: :updated_after))
  end

  def create_params
    params.require(:conversation).permit(
      :inbox_id, :contact_id, :status, :assignee_id, :team_id,
      additional_attributes: {}, custom_attributes: {},
      message: [:content, :private, :content_type, :to_emails, :cc_emails, :bcc_emails, :email_html_content]
    )
  end

  def update_params
    params.require(:conversation).permit(:status, :priority, :assignee_id, :team_id, :snoozed_until, labels: [])
  end

  def create_conversation_result
    record = build_conversation
    response_status = record.previously_new_record? ? :created : :ok
    apply_initial_assignment(record)
    create_initial_message(record)
    idempotent_result(status: response_status, body: { data: present(persisted_copy(record)) }, resource: record)
  end

  # Conversation#display_id is assigned by a PostgreSQL trigger. The original
  # instance must retain previous_changes for its after_commit dispatcher, so
  # present a fresh copy instead of reloading it inside this transaction.
  def persisted_copy(record)
    Conversation.find(record.id)
  end

  def build_conversation
    ConversationBuilder.new(
      params: conversation_builder_params,
      contact_inbox: build_contact_inbox
    ).perform
  end

  def build_contact_inbox
    contact = openjarvis_access_scope.contact!(create_params[:contact_id])
    inbox = openjarvis_access_scope.inbox!(create_params[:inbox_id])
    Openjarvis::ContactInboxResolver.new(contact: contact, inbox: inbox).resolve!
  end

  def conversation_builder_params
    excluded = [:inbox_id, :contact_id, :message, :assignee_id, :team_id]
    ActionController::Parameters.new(create_params.except(*excluded).to_h)
  end

  def create_initial_message(created_conversation)
    message = create_params[:message]
    return if message.blank?

    Messages::MessageBuilder.new(Current.user, created_conversation, ActionController::Parameters.new(message.to_h)).perform
  end

  def apply_conversation_updates
    update_conversation_attributes
    update_team(conversation, update_params[:team_id]) if update_params.key?(:team_id)
    update_assignee(conversation, update_params[:assignee_id]) if update_params.key?(:assignee_id)
    update_conversation_labels
  end

  def update_conversation_attributes
    attributes = update_params.slice(:status, :priority, :snoozed_until)
    conversation.update!(attributes) if attributes.present?
  end

  def update_conversation_labels
    return unless update_params.key?(:labels)

    titles = Openjarvis::ResourceResolver.new(openjarvis_access_scope).label_titles!(update_params[:labels])
    conversation.update_labels(titles)
  end

  def apply_initial_assignment(record)
    update_team(record, create_params[:team_id]) if create_params.key?(:team_id)
    update_assignee(record, create_params[:assignee_id]) if create_params.key?(:assignee_id)
  end

  def validate_create_params!
    if params.dig(:conversation, :source_id).present?
      raise Openjarvis::ApiError.new(
        'source_id_not_accepted',
        'source_id is resolved by AceleraChat and must not be supplied by the client',
        status: :bad_request
      )
    end
    validate_enum_value!(Conversation, :status, create_params[:status])
  end

  def validate_update_params!
    validate_enum_value!(Conversation, :status, update_params[:status])
    validate_enum_value!(Conversation, :priority, update_params[:priority])
    parse_iso8601!(update_params[:snoozed_until], parameter: :snoozed_until) if update_params[:snoozed_until].present?
  end

  def update_assignee(record, assignee_id)
    Openjarvis::ResourceResolver.new(openjarvis_access_scope).agent!(assignee_id, inbox: record.inbox) if assignee_id.present?
    Conversations::AssignmentService.new(
      conversation: record,
      assignee_id: assignee_id
    ).perform
  rescue ActiveRecord::RecordNotFound
    raise Openjarvis::ApiError.new(
      'assignee_not_authorized',
      'Assignee is outside the authorized account, inbox or team scope',
      status: :forbidden
    )
  end

  def update_team(record, team_id)
    team = team_id.present? ? Openjarvis::ResourceResolver.new(openjarvis_access_scope).team!(team_id) : nil

    record.update!(team: team)
  end

  def present(record)
    Openjarvis::ConversationPresenter.new(record).as_json
  end
end
