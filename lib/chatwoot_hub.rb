# Compatibility facade for legacy internal callers.
# External communication is delegated exclusively to AceleraControl.
class ChatwootHub
  def self.base_url
    AceleraControl.base_url
  end

  def self.ping_url
    AceleraControl.heartbeat_url
  end

  def self.registration_url
    nil
  end

  def self.push_notification_url
    nil
  end

  def self.events_url
    nil
  end

  def self.billing_base_url
    AceleraControl.billing_url
  end

  def self.installation_identifier
    identifier = InstallationConfig.find_by(name: 'INSTALLATION_IDENTIFIER')&.value
    identifier ||= InstallationConfig.create!(name: 'INSTALLATION_IDENTIFIER', value: SecureRandom.uuid).value
    identifier
  end

  def self.billing_url
    billing_base_url
  end

  def self.pricing_plan
    return 'community' unless ChatwootApp.enterprise?

    local_plan = InstallationConfig.find_by(name: 'INSTALLATION_PRICING_PLAN')&.value || 'community'
    return local_plan unless AceleraControl.managed?

    AceleraControl.entitlement_active? ? local_plan : 'community'
  end

  def self.pricing_plan_quantity
    return 0 unless ChatwootApp.enterprise?
    return 0 if AceleraControl.managed? && !AceleraControl.entitlement_active?

    InstallationConfig.find_by(name: 'INSTALLATION_PRICING_PLAN_QUANTITY')&.value || 0
  end

  def self.support_config
    support_script_url = AceleraControl.safe_external_url(
      InstallationConfig.find_by(name: 'CHATWOOT_SUPPORT_SCRIPT_URL')&.value
    )
    return { support_website_token: nil, support_script_url: nil, support_identifier_hash: nil } if support_script_url.blank?

    {
      support_website_token: InstallationConfig.find_by(name: 'CHATWOOT_SUPPORT_WEBSITE_TOKEN')&.value,
      support_script_url: support_script_url,
      support_identifier_hash: InstallationConfig.find_by(name: 'CHATWOOT_SUPPORT_IDENTIFIER_HASH')&.value
    }
  end

  def self.instance_config
    {
      instance_id: installation_identifier,
      app_version: Chatwoot.config[:version],
      source_sha: defined?(GIT_HASH) ? GIT_HASH : nil,
      deployment_env: ENV.fetch('INSTALLATION_ENV', ''),
      edition: ENV.fetch('CW_EDITION', '')
    }.compact
  end

  def self.instance_metrics
    {
      active_users_count: User.count
    }
  end

  def self.sync_with_hub
    info = instance_config
    info = info.merge(instance_metrics) if include_usage_metrics?
    AceleraControl.heartbeat(info)
  end

  def self.register_instance(*)
    false
  end

  def self.send_push(*)
    false
  end

  def self.send_push_with_response(*)
    false
  end

  def self.emit_event(*)
    false
  end

  def self.push_relay_available?
    false
  end

  def self.include_usage_metrics?
    return false if ActiveModel::Type::Boolean.new.cast(ENV.fetch('DISABLE_TELEMETRY', false))

    ActiveModel::Type::Boolean.new.cast(ENV.fetch('ACELERA_CONTROL_INCLUDE_USAGE', false))
  end
end

ChatwootHub.singleton_class.prepend_mod_with('ChatwootHub')
