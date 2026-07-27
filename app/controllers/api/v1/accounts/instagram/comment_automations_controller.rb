class Api::V1::Accounts::Instagram::CommentAutomationsController < Api::V1::Accounts::BaseController
  before_action -> { check_authorization(InstagramCommentAutomation) }
  before_action :inbox
  before_action :automation, only: [:show, :update, :destroy]
  before_action :ensure_subscription_ready, only: [:create, :update]

  def index
    render json: {
      payload: inbox.instagram_comment_automations.order(priority: :desc, created_at: :asc).map { |item| serialize(item) }
    }
  end

  def show
    render json: serialize(automation)
  end

  def create
    item = inbox.instagram_comment_automations.new(automation_params)
    item.account = Current.account
    item.created_by = current_user
    item.updated_by = current_user
    item.save!

    render json: serialize(item), status: :created
  end

  def update
    automation.assign_attributes(automation_params)
    automation.updated_by = current_user
    automation.save!

    render json: serialize(automation)
  rescue ActiveRecord::StaleObjectError
    render json: { error: 'The automation was changed by another administrator. Reload and try again.' }, status: :conflict
  end

  def destroy
    automation.destroy!
    head :ok
  end

  private

  def inbox
    @inbox ||= Current.account.inboxes.find(params.require(:inbox_id))
    raise ActiveRecord::RecordNotFound unless @inbox.instagram?

    @inbox
  end

  def automation
    @automation ||= inbox.instagram_comment_automations.find(params[:id])
  end

  def automation_params
    params.require(:comment_automation).permit(
      :name,
      :enabled,
      :match_type,
      :media_id,
      :include_nested_replies,
      :public_reply_enabled,
      :public_reply_template,
      :private_reply_enabled,
      :private_reply_template,
      :conversation_context,
      :conversation_label,
      :priority,
      :starts_at,
      :ends_at,
      :lock_version,
      keywords: []
    )
  end

  def ensure_subscription_ready
    return unless ActiveModel::Type::Boolean.new.cast(automation_params[:enabled])

    result = Instagram::CommentAutomation::WebhookSubscriptionService.new(inbox.channel).status
    return if result.success? && result.missing_fields.empty?

    render json: {
      error: 'Instagram comment webhooks are not active for this inbox.',
      code: 'instagram_comment_subscription_required',
      missing_fields: result.missing_fields
    }, status: :unprocessable_entity
  end

  def serialize(item)
    item.as_json(
      only: [
        :id, :name, :enabled, :match_type, :keywords, :media_id, :include_nested_replies,
        :public_reply_enabled, :public_reply_template, :private_reply_enabled,
        :private_reply_template, :conversation_context, :conversation_label, :priority,
        :starts_at, :ends_at, :lock_version, :created_at, :updated_at
      ]
    )
  end
end
