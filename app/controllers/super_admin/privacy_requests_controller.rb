class SuperAdmin::PrivacyRequestsController < SuperAdmin::ApplicationController
  before_action :set_privacy_request, only: %i[show update]

  def index
    @status = params[:status].presence
    scope = PrivacyRequest.order(created_at: :desc)
    scope = scope.where(status: PrivacyRequest.statuses.fetch(@status)) if PrivacyRequest.statuses.key?(@status)
    @privacy_requests = scope.page(params[:page]).per(50)
  end

  def show; end

  def update
    target_status = params.require(:privacy_request).fetch(:status)
    return redirect_invalid_transition unless transition_allowed?(target_status)

    transition_request!(target_status)
    send_status_email
    redirect_to super_admin_privacy_request_path(@privacy_request), notice: I18n.t('acelerachat.privacy_requests.updated')
  rescue ArgumentError, ActiveRecord::RecordNotFound => e
    redirect_to super_admin_privacy_request_path(@privacy_request), alert: e.message
  end

  private

  def transition_request!(target_status)
    PrivacyRequest.transaction do
      link_requested_account!
      @privacy_request.transition_to!(
        target_status,
        actor: current_super_admin,
        notes: params.dig(:privacy_request, :resolution_notes),
        subprocessor_actions: requested_subprocessor_actions
      )
    end
  end

  def requested_subprocessor_actions
    params.dig(:privacy_request, :subprocessor_actions).to_s.lines.map(&:strip).reject(&:blank?)
  end

  def transition_allowed?(target_status)
    permitted_transitions.fetch(@privacy_request.status).include?(target_status)
  end

  def redirect_invalid_transition
    redirect_to super_admin_privacy_request_path(@privacy_request), alert: I18n.t('acelerachat.privacy_requests.invalid_transition')
  end

  def set_privacy_request
    @privacy_request = PrivacyRequest.includes(:events).find(params[:id])
  end

  def permitted_transitions
    {
      'pending_verification' => [],
      'verified' => %w[in_review completed rejected],
      'in_review' => %w[completed rejected],
      'completed' => [],
      'rejected' => []
    }
  end

  def link_requested_account!
    account_id = params.dig(:privacy_request, :account_id).presence
    return unless account_id

    @privacy_request.link_account!(Account.find(account_id), actor: current_super_admin)
  end

  def send_status_email
    return if @privacy_request.email.blank?

    PrivacyRequestMailer.with(privacy_request: @privacy_request, locale: @privacy_request.locale).status_updated.deliver_now
  rescue StandardError => e
    Rails.logger.error("Privacy request status email failed for protocol #{@privacy_request.protocol}: #{e.class}")
  end
end
