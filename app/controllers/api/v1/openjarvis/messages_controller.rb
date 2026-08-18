class Api::V1::Openjarvis::MessagesController < Api::V1::Openjarvis::BaseController
  def index
    require_scope!('messages:read')
    records = conversation.messages.includes(:sender, attachments: { file_attachment: :blob }).reorder(created_at: :desc)
    records = records.where('messages.id < ?', before_id) if before_id
    records = records.limit(limit)
    render json: { data: records.map { |message| present(message) }, meta: { limit: limit, returned: records.size } }
  end

  def create
    require_scope!('messages:write')
    execute_idempotently('messages.create', message_params.merge(conversation_id: conversation.display_id)) do
      message = Messages::MessageBuilder.new(Current.user, conversation, ActionController::Parameters.new(message_params.to_h)).perform
      idempotent_result(status: :created, body: { data: present(message) }, resource: message)
    end
  end

  private

  def conversation
    @conversation ||= openjarvis_access_scope.conversation!(params[:conversation_id])
  end

  def message_params
    params.require(:message).permit(
      :content, :private, :content_type, :to_emails, :cc_emails, :bcc_emails,
      :email_html_content, content_attributes: {}
    )
  end

  def before_id
    return if params[:before_id].blank?

    value = Integer(params[:before_id], exception: false)
    return value if value&.positive?

    raise Openjarvis::ApiError.new('invalid_before_id', 'before_id must be a positive integer', status: :bad_request)
  end

  def present(message)
    Openjarvis::MessagePresenter.new(message).as_json
  end
end
