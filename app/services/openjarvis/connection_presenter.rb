class Openjarvis::ConnectionPresenter
  def initialize(hook:, user:, public_base_url:)
    @hook = hook
    @user = user
    @public_base_url = public_base_url.to_s.delete_suffix('/')
  end

  def as_json(credentials: nil)
    payload = hook ? configured_payload : unconfigured_payload
    payload[:credentials] = credentials if credentials
    payload
  end

  private

  attr_reader :hook, :user, :public_base_url

  def configured_payload
    configuration = hook.openjarvis_configuration
    {
      configured: true,
      enabled: hook.enabled?,
      status: connection_status(configuration),
      settings: public_settings(configuration),
      warnings: configuration_warnings(configuration),
      api_base_url: "#{public_base_url}/api/v1/openjarvis",
      credential_metadata: credential_metadata
    }
  end

  def unconfigured_payload
    { configured: false, enabled: false, status: 'not_configured', settings: defaults }
  end

  def defaults
    {
      endpoint_url: '',
      service_user_id: user.id,
      inbox_access_mode: 'all_account',
      allowed_inbox_ids: [],
      scopes: Openjarvis::Configuration::DEFAULT_SCOPES,
      subscriptions: Openjarvis::Configuration::DEFAULT_SUBSCRIPTIONS,
      webhooks_enabled: false
    }
  end

  def credential_metadata
    {
      access_token_last_four: hook.access_token.to_s.last(4),
      access_token_rotated_at: hook.access_token_rotated_at&.iso8601,
      previous_access_token_expires_at: hook.previous_access_token_expires_at&.iso8601,
      webhook_secret_last_four: hook.webhook_secret.to_s.last(4),
      webhook_secret_rotated_at: hook.webhook_secret_rotated_at&.iso8601,
      previous_webhook_secret_expires_at: hook.previous_webhook_secret_expires_at&.iso8601
    }
  end

  def connection_status(configuration)
    return 'disabled' if hook.disabled?
    return 'awaiting_openjarvis' if configuration.endpoint_url.blank?

    hook.settings['last_test_status'].presence || 'not_tested'
  end

  def public_settings(configuration)
    defaults.merge(hook.settings.to_h.symbolize_keys).merge(
      allowed_inbox_ids: configuration.existing_allowed_inbox_ids
    )
  end

  def configuration_warnings(configuration)
    return {} if configuration.stale_allowed_inbox_ids.empty?

    { removed_inbox_ids: configuration.stale_allowed_inbox_ids }
  end
end
