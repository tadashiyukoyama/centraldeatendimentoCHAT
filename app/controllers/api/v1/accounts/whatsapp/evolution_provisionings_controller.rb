class Api::V1::Accounts::Whatsapp::EvolutionProvisioningsController < Api::V1::Accounts::BaseController
  before_action :authorize_inbox_creation!
  before_action :set_provisioning, except: :create

  def show
    result = Whatsapp::Evolution::ConnectionSyncService.new(provisioning: @provisioning).perform
    render json: response_payload(result.provisioning, result.qr_code)
  rescue Whatsapp::Evolution::ApiClient::Error, ActiveRecord::RecordInvalid, ArgumentError => e
    render json: { error: safe_error_message(e), status: @provisioning.reload.status }, status: :unprocessable_entity
  end

  def create
    result = Whatsapp::Evolution::ProvisioningService.new(
      account: Current.account,
      inbox_name: params.require(:inbox_name)
    ).perform
    render json: response_payload(result.provisioning, result.qr_code), status: :created
  rescue Whatsapp::Evolution::Configuration::ConfigurationError, Whatsapp::Evolution::ApiClient::Error,
         ActiveRecord::RecordInvalid, ArgumentError => e
    render json: { error: safe_error_message(e) }, status: :unprocessable_entity
  end

  def reconnect
    result = Whatsapp::Evolution::ConnectionSyncService.new(provisioning: @provisioning).perform
    render json: response_payload(result.provisioning, result.qr_code)
  rescue Whatsapp::Evolution::ApiClient::Error, ActiveRecord::RecordInvalid, ArgumentError => e
    render json: { error: safe_error_message(e), status: @provisioning.reload.status }, status: :unprocessable_entity
  end

  def disconnect
    Whatsapp::Evolution::ApiClient.new(provisioning: @provisioning).logout
    @provisioning.update!(status: :disconnected, last_seen_at: Time.current)
    render json: response_payload(@provisioning, nil)
  rescue Whatsapp::Evolution::ApiClient::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    Whatsapp::Evolution::TeardownService.new(@provisioning).perform
    head :no_content
  rescue Whatsapp::Evolution::ApiClient::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def authorize_inbox_creation!
    authorize Current.account.inboxes.new, :create?
  end

  def set_provisioning
    @provisioning = Current.account.whatsapp_evolution_provisionings.find_by!(public_id: params[:public_id])
  end

  def response_payload(provisioning, qr_code)
    {
      id: provisioning.public_id,
      status: provisioning.status,
      qr_code: qr_code,
      expires_at: provisioning.expires_at,
      connected_number: provisioning.connected_number,
      profile_name: provisioning.profile_name,
      inbox_id: provisioning.inbox&.id
    }.compact
  end

  def safe_error_message(error)
    return error.message if error.is_a?(Whatsapp::Evolution::Configuration::ConfigurationError)
    return error.message if error.is_a?(Whatsapp::Evolution::ApiClient::Error)
    return error.record.errors.full_messages.to_sentence if error.is_a?(ActiveRecord::RecordInvalid)

    error.message
  end
end
