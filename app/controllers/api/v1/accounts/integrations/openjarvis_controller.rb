class Api::V1::Accounts::Integrations::OpenjarvisController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :load_hook, except: [:show, :update]

  def show
    @hook = Current.account.hooks.find_by(app_id: Openjarvis::Configuration::APP_ID)
    render json: connection_payload
  end

  def update
    @hook = Current.account.hooks.find_or_initialize_by(app_id: Openjarvis::Configuration::APP_ID)
    created = @hook.new_record?
    @hook.assign_attributes(status: requested_status, settings: merged_settings)
    if created
      @hook.access_token_rotated_at = Time.current
      @hook.webhook_secret_rotated_at = Time.current
    end
    @hook.save!
    render json: connection_payload(credentials: credential_payload_if(created))
  end

  def destroy
    @hook.update!(
      status: :disabled,
      access_token: self.class.generate_token,
      webhook_secret: self.class.generate_token,
      previous_access_token: nil,
      previous_access_token_expires_at: nil,
      previous_webhook_secret: nil,
      previous_webhook_secret_expires_at: nil,
      access_token_rotated_at: Time.current,
      webhook_secret_rotated_at: Time.current,
      settings: @hook.settings.merge('webhooks_enabled' => false)
    )
    render json: connection_payload
  end

  def rotate_access_token
    token = self.class.generate_token
    grace_expires_at = Openjarvis::Configuration::CREDENTIAL_GRACE_PERIOD.from_now
    @hook.update!(
      previous_access_token: @hook.access_token,
      previous_access_token_expires_at: grace_expires_at,
      access_token: token,
      access_token_rotated_at: Time.current
    )
    render json: {
      credential: {
        type: 'bearer', value: token, rotated_at: @hook.access_token_rotated_at.iso8601,
        previous_valid_until: grace_expires_at.iso8601
      }
    }
  end

  def rotate_webhook_secret
    secret = self.class.generate_token
    grace_expires_at = Openjarvis::Configuration::CREDENTIAL_GRACE_PERIOD.from_now
    @hook.update!(
      previous_webhook_secret: @hook.webhook_secret,
      previous_webhook_secret_expires_at: grace_expires_at,
      webhook_secret: secret,
      webhook_secret_rotated_at: Time.current
    )
    render json: {
      credential: {
        type: 'hmac_sha256', value: secret, rotated_at: @hook.webhook_secret_rotated_at.iso8601,
        previous_valid_until: grace_expires_at.iso8601
      }
    }
  end

  def test_connection
    configuration = @hook.openjarvis_configuration
    raise Openjarvis::ApiError.new('missing_endpoint', 'Configure the OpenJarvis webhook endpoint first') if configuration.endpoint_url.blank?

    payload = Openjarvis::IntegrationTestPayload.new(hook: @hook, account: Current.account).as_json
    webhook_client(configuration).deliver(payload, delivery_id: SecureRandom.uuid)
    record_test_result('connected')
    render json: connection_payload
  rescue Openjarvis::WebhookClient::DeliveryError, Openjarvis::ApiError => e
    record_test_result('unreachable', e.message) if @hook
    render json: connection_payload.merge(error: { code: 'openjarvis_unreachable', message: e.message }), status: :unprocessable_entity
  end

  def deliveries
    records = @hook.openjarvis_webhook_deliveries.order(created_at: :desc).limit(50)
    render json: {
      data: records.map do |item|
        item.slice(
          :delivery_id, :event_id, :schema_version, :event_name, :resource_type, :resource_id,
          :resource_version, :resource_sequence, :status, :attempts, :response_status,
          :failure_class, :error_code, :error_message, :next_attempt_at, :created_at, :delivered_at
        )
      end
    }
  end

  def self.generate_token
    SecureRandom.urlsafe_base64(48)
  end

  private

  def check_authorization
    authorize(:hook, action_name == 'destroy' ? :destroy? : :update?)
  end

  def load_hook
    @hook = Current.account.hooks.find_by!(app_id: Openjarvis::Configuration::APP_ID)
  end

  def requested_status
    ActiveModel::Type::Boolean.new.cast(params.fetch(:enabled, true)) ? :enabled : :disabled
  end

  def submitted_settings
    params.require(:openjarvis).permit(
      :endpoint_url, :service_user_id, :webhooks_enabled,
      allowed_inbox_ids: [], scopes: [], subscriptions: []
    ).to_h
  end

  def merged_settings
    system_settings = @hook.settings.to_h.slice('last_test_at', 'last_test_status', 'last_test_error')
    submitted_settings.merge(system_settings)
  end

  def defaults
    {
      endpoint_url: '',
      service_user_id: Current.user.id,
      allowed_inbox_ids: Current.account.inboxes.pluck(:id),
      scopes: Openjarvis::Configuration::DEFAULT_SCOPES,
      subscriptions: Openjarvis::Configuration::DEFAULT_SUBSCRIPTIONS,
      webhooks_enabled: false
    }
  end

  def connection_payload(credentials: nil)
    payload = @hook ? configured_connection_payload : unconfigured_connection_payload
    payload[:credentials] = credentials if credentials
    payload
  end

  def configured_connection_payload
    configuration = @hook.openjarvis_configuration
    public_base_url = (ENV['FRONTEND_URL'].presence || request.base_url).to_s.delete_suffix('/')
    {
      configured: true,
      enabled: @hook.enabled?,
      status: connection_status(configuration),
      settings: defaults.merge(@hook.settings.to_h.symbolize_keys),
      api_base_url: "#{public_base_url}/api/v1/openjarvis",
      credential_metadata: credential_metadata
    }
  end

  def unconfigured_connection_payload
    { configured: false, enabled: false, status: 'not_configured', settings: defaults }
  end

  def credential_metadata
    {
      access_token_last_four: @hook.access_token.to_s.last(4),
      access_token_rotated_at: @hook.access_token_rotated_at&.iso8601,
      previous_access_token_expires_at: @hook.previous_access_token_expires_at&.iso8601,
      webhook_secret_last_four: @hook.webhook_secret.to_s.last(4),
      webhook_secret_rotated_at: @hook.webhook_secret_rotated_at&.iso8601,
      previous_webhook_secret_expires_at: @hook.previous_webhook_secret_expires_at&.iso8601
    }
  end

  def connection_status(configuration)
    return 'disabled' if @hook.disabled?
    return 'awaiting_openjarvis' if configuration.endpoint_url.blank?

    @hook.settings['last_test_status'].presence || 'not_tested'
  end

  def credential_payload_if(created)
    return unless created

    {
      access_token: @hook.access_token,
      webhook_secret: @hook.webhook_secret
    }
  end

  def record_test_result(status, error = nil)
    settings = @hook.settings.merge(
      'last_test_at' => Time.current.iso8601,
      'last_test_status' => status,
      'last_test_error' => error.to_s.squish.first(300).presence
    )
    @hook.update!(settings: settings)
  end

  def webhook_client(configuration)
    Openjarvis::WebhookClient.new(endpoint_url: configuration.endpoint_url, secrets: @hook.active_openjarvis_webhook_secrets)
  end
end
