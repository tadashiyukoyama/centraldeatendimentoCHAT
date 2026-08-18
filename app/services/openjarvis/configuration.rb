class Openjarvis::Configuration
  APP_ID = 'openjarvis'.freeze
  DEFAULT_SCOPES = %w[
    inboxes:read conversations:read messages:read messages:write
    contacts:read contacts:write conversations:write diagnostics:read
  ].freeze
  SCOPES = DEFAULT_SCOPES.freeze
  DEFAULT_SUBSCRIPTIONS = %w[
    message.created message.updated conversation.created conversation.updated
    conversation.status_changed contact.created contact.updated
  ].freeze
  SUBSCRIPTIONS = DEFAULT_SUBSCRIPTIONS.freeze
  BLOCKED_HOSTS = %w[chatwoot.com chatwoot.help chwt.app].freeze

  attr_reader :hook

  def initialize(hook)
    @hook = hook
  end

  def endpoint_url
    settings['endpoint_url'].to_s.strip
  end

  def service_user_id
    settings['service_user_id'].to_i
  end

  def service_user
    hook.account.users.find_by(id: service_user_id)
  end

  def account_user
    hook.account.account_users.find_by(user_id: service_user_id)
  end

  def allowed_inbox_ids
    Array(settings['allowed_inbox_ids']).filter_map { |value| Integer(value, exception: false) }.uniq
  end

  def scopes
    Array(settings['scopes']).map(&:to_s).uniq
  end

  def subscriptions
    Array(settings['subscriptions']).map(&:to_s).uniq
  end

  def webhooks_enabled?
    ActiveModel::Type::Boolean.new.cast(settings['webhooks_enabled'])
  end

  def errors
    [].tap do |result|
      validate_encryption(result)
      validate_service_user(result)
      validate_inboxes(result)
      validate_values(result)
      validate_endpoint(result)
    end
  end

  def valid?
    errors.empty?
  end

  private

  def settings
    @settings ||= hook.settings.to_h.stringify_keys
  end

  def validate_encryption(result)
    return unless Rails.env.production?
    return if Chatwoot.encryption_configured?

    result << 'Active Record encryption is required in production'
  end

  def validate_service_user(result)
    result << 'Service user must belong to this account' if account_user.blank? || service_user.blank?
  end

  def validate_inboxes(result)
    return result << 'Select at least one inbox' if allowed_inbox_ids.empty?

    result << 'One or more inboxes do not belong to this account' if missing_inbox_ids.any?
    return if account_user.blank? || account_user.administrator?

    result << 'Service user cannot access one or more selected inboxes' if inaccessible_inbox_ids.any?
  end

  def missing_inbox_ids
    allowed_inbox_ids - hook.account.inboxes.where(id: allowed_inbox_ids).pluck(:id)
  end

  def inaccessible_inbox_ids
    allowed_inbox_ids - service_user.inboxes.where(account_id: hook.account_id).pluck(:id)
  end

  def validate_values(result)
    result << 'Select at least one API scope' if scopes.empty?
    result << 'Unsupported API scope' if (scopes - SCOPES).any?
    result << 'Unsupported webhook subscription' if (subscriptions - SUBSCRIPTIONS).any?
  end

  def validate_endpoint(result)
    if endpoint_url.blank?
      result << 'Webhook endpoint is required when webhooks are enabled' if webhooks_enabled?
      return
    end

    validate_endpoint_uri(result, URI.parse(endpoint_url))
  rescue URI::InvalidURIError
    result << 'Webhook endpoint is invalid'
  end

  def validate_endpoint_uri(result, uri)
    result << 'Webhook endpoint must use HTTPS' unless uri.is_a?(URI::HTTPS)
    result << 'Webhook endpoint must include a host' if uri.host.blank?
    result << 'Webhook endpoint cannot contain embedded credentials' if uri.userinfo.present?
    result << 'Webhook endpoint cannot contain a query string' if uri.query.present?
    result << 'Webhook endpoint cannot contain a fragment' if uri.fragment.present?
    result << 'Webhook endpoint cannot use an old Chatwoot domain' if blocked_host?(uri.host)
  end

  def blocked_host?(value)
    host = value.to_s.downcase.delete_suffix('.')
    BLOCKED_HOSTS.any? { |blocked| host == blocked || host.end_with?(".#{blocked}") }
  end
end
