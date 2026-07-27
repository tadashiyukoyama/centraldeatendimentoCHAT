class Api::V1::Accounts::Instagram::CommentEventsController < Api::V1::Accounts::BaseController
  before_action -> { check_authorization(InstagramCommentAutomation) }

  def index
    inbox = Current.account.inboxes.find(params.require(:inbox_id))
    raise ActiveRecord::RecordNotFound unless inbox.instagram?

    events = inbox.instagram_comment_events.includes(:instagram_comment_automation)
                  .order(created_at: :desc)
                  .limit(limit)

    render json: { payload: events.map { |event| serialize(event) } }
  end

  private

  def limit
    params.fetch(:limit, 50).to_i.clamp(1, 100)
  end

  def serialize(event)
    {
      id: event.id,
      automation_id: event.instagram_comment_automation_id,
      automation_name: event.instagram_comment_automation&.name,
      comment_id: event.comment_id,
      sender_username: event.sender_username,
      media_id: event.media_id,
      comment_text: event.comment_text,
      webhook_field: event.webhook_field,
      status: event.status,
      ignore_reason: event.ignore_reason,
      matched_keyword: event.matched_keyword,
      public_reply_status: event.public_reply_status,
      private_reply_status: event.private_reply_status,
      error_codes: [event.public_reply_error_code, event.private_reply_error_code].compact.uniq,
      conversation_id: event.conversation_id,
      received_at: event.received_at,
      processed_at: event.processed_at
    }
  end
end
