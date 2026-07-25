class Internal::ReconcilePlanConfigService
  def perform
    remove_premium_config_reset_warning
    return if ChatwootHub.pricing_plan != 'community'

    reconcile_premium_features
  end

  private

  def remove_premium_config_reset_warning
    Redis::Alfred.delete(Redis::Alfred::CHATWOOT_INSTALLATION_CONFIG_RESET_WARNING)
  end

  def premium_features
    @premium_features ||= YAML.safe_load(File.read(Rails.root.join('enterprise/config/premium_features.yml'))).freeze
  end

  def reconcile_premium_features
    Account.find_in_batches do |accounts|
      accounts.each do |account|
        account.disable_features!(*premium_features)
      end
    end
  end
end
