class Whatsapp::Evolution::CleanupExpiredProvisioningsJob < ApplicationJob
  queue_as :housekeeping

  def perform
    return unless Whatsapp::Evolution::Configuration.enabled?

    Whatsapp::EvolutionProvisioning.expired_pending.find_each do |provisioning|
      Whatsapp::Evolution::TeardownService.new(provisioning).perform
    rescue StandardError => e
      Rails.logger.error(
        "[EVOLUTION] Expired provisioning cleanup failed provisioning_id=#{provisioning.id} error=#{e.class.name}"
      )
    end
  end
end
