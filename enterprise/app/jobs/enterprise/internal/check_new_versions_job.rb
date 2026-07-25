module Enterprise::Internal::CheckNewVersionsJob
  SUPPORTED_PLANS = %w[community premium enterprise].freeze
  RESPONSE_CONFIG_MAPPING = {
    'plan_quantity' => 'INSTALLATION_PRICING_PLAN_QUANTITY',
    'chatwoot_support_website_token' => 'CHATWOOT_SUPPORT_WEBSITE_TOKEN',
    'chatwoot_support_identifier_hash' => 'CHATWOOT_SUPPORT_IDENTIFIER_HASH',
    'chatwoot_support_script_url' => 'CHATWOOT_SUPPORT_SCRIPT_URL',
    'acelera_entitlements' => 'ACELERA_CONTROL_ENTITLEMENTS',
    'acelera_entitlement_status' => 'ACELERA_CONTROL_STATUS',
    'acelera_entitlement_expires_at' => 'ACELERA_CONTROL_EXPIRES_AT',
    'acelera_entitlement_grace_until' => 'ACELERA_CONTROL_GRACE_UNTIL',
    'acelera_release_sha' => 'ACELERA_CONTROL_RELEASE_SHA'
  }.freeze

  def perform
    super
    update_plan_info
    reconcile_premium_config_and_features
  end

  private

  def update_plan_info
    return if @instance_info.blank?

    update_plan if SUPPORTED_PLANS.include?(@instance_info['plan'])

    RESPONSE_CONFIG_MAPPING.each do |response_key, config_key|
      next unless @instance_info.key?(response_key)

      update_installation_config(key: config_key, value: @instance_info[response_key])
    end
  end

  def update_plan
    update_installation_config(key: 'INSTALLATION_PRICING_PLAN', value: @instance_info['plan'])
  end

  def update_installation_config(key:, value:)
    config = InstallationConfig.find_or_initialize_by(name: key)
    config.value = value
    config.locked = true
    config.save!
  end

  def reconcile_premium_config_and_features
    Internal::ReconcilePlanConfigService.new.perform
  end
end
