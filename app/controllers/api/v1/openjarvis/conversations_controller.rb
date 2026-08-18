class Api::V1::Openjarvis::ConversationsController < Api::V1::Openjarvis::BaseController
  def index
    require_scope!('conversations:read')
    records = filtered_conversations
    records = paginate(records.includes(:inbox, :contact, :assignee, :team).order(updated_at: :desc))
    render json: { data: records.map { |conversation| present(conversation) }, meta: pagination_meta(records) }
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

  private

  def conversation
    @conversation ||= openjarvis_access_scope.conversation!(params[:id])
  end

  def filtered_conversations
    scope = openjarvis_access_scope.conversations
    scope = scope.where(inbox_id: params[:inbox_id]) if params[:inbox_id].present?
    if params[:status].present?
      validate_enum_value!(Conversation, :status, params[:status])
      scope = scope.where(status: params[:status])
    end
    if params[:updated_after].present?
      scope = scope.where('conversations.updated_at >= ?', parse_iso8601!(params[:updated_after], parameter: :updated_after))
    end
    scope
  end

  def create_params
    params.require(:conversation).permit(
      :inbox_id, :contact_id, :source_id, :status, :assignee_id, :team_id,
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
    idempotent_result(status: response_status, body: { data: present(record) }, resource: record)
  end

  def build_conversation
    ConversationBuilder.new(
      params: conversation_builder_params,
      contact_inbox: build_contact_inbox
    ).perform
  end

  def build_contact_inbox
    ContactInboxBuilder.new(
      contact: openjarvis_access_scope.contact!(create_params[:contact_id]),
      inbox: openjarvis_access_scope.inbox!(create_params[:inbox_id]),
      source_id: create_params[:source_id]
    ).perform
  end

  def conversation_builder_params
    excluded = [:inbox_id, :contact_id, :source_id, :message, :assignee_id, :team_id]
    ActionController::Parameters.new(create_params.except(*excluded).to_h)
  end

  def create_initial_message(created_conversation)
    message = create_params[:message]
    return if message.blank?

    Messages::MessageBuilder.new(Current.user, created_conversation, ActionController::Parameters.new(message.to_h)).perform
  end

  def apply_conversation_updates
    attributes = update_params.slice(:status, :priority, :snoozed_until)
    conversation.update!(attributes) if attributes.present?
    update_team(conversation, update_params[:team_id]) if update_params.key?(:team_id)
    update_assignee(conversation, update_params[:assignee_id]) if update_params.key?(:assignee_id)
    conversation.update_labels(update_params[:labels]) if update_params.key?(:labels)
  end

  def apply_initial_assignment(record)
    update_team(record, create_params[:team_id]) if create_params.key?(:team_id)
    update_assignee(record, create_params[:assignee_id]) if create_params.key?(:assignee_id)
  end

  def validate_create_params!
    validate_enum_value!(Conversation, :status, create_params[:status])
  end

  def validate_update_params!
    validate_enum_value!(Conversation, :status, update_params[:status])
    validate_enum_value!(Conversation, :priority, update_params[:priority])
    parse_iso8601!(update_params[:snoozed_until], parameter: :snoozed_until) if update_params[:snoozed_until].present?
  end

  def update_assignee(record, assignee_id)
    Current.account.users.find(assignee_id) if assignee_id.present?
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
    team = team_id.present? ? Current.account.teams.find_by(id: team_id) : nil
    if team_id.present? && team.blank?
      raise Openjarvis::ApiError.new('team_not_authorized', 'Team is outside the authorized account scope', status: :forbidden)
    end
    unless Current.account_user.administrator? || team.nil? || Current.user.teams.exists?(id: team.id)
      raise Openjarvis::ApiError.new('team_not_authorized', 'Service user cannot assign this team', status: :forbidden)
    end

    record.update!(team: team)
  end

  def present(record)
    Openjarvis::ConversationPresenter.new(record).as_json
  end
end
