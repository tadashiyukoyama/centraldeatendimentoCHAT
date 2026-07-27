class Api::V1::Accounts::Instagram::CommentWebhookSubscriptionsController < Api::V1::Accounts::BaseController
  before_action -> { check_authorization(InstagramCommentAutomation) }
  before_action :inbox

  def show
    render_result(subscription_service.status)
  end

  def create
    render_result(subscription_service.subscribe)
  end

  private

  def inbox
    @inbox ||= Current.account.inboxes.find(params.require(:inbox_id))
    raise ActiveRecord::RecordNotFound unless @inbox.instagram?

    @inbox
  end

  def subscription_service
    @subscription_service ||= Instagram::CommentAutomation::WebhookSubscriptionService.new(inbox.channel)
  end

  def render_result(result)
    status = result.success? ? :ok : :unprocessable_entity
    render json: {
      success: result.success?,
      subscribed_fields: result.subscribed_fields,
      missing_fields: result.missing_fields,
      error_code: result.error_code,
      error_type: result.error_type,
      reauthorization_required: !result.success? || result.missing_fields.any?
    }, status: status
  end
end
