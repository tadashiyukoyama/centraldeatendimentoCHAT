class PrivacyRequestCleanupJob < ApplicationJob
  queue_as :purgable

  def perform
    PrivacyRequest.unverified_expired.find_each(&:destroy!)
    PrivacyRequest.sensitive_data_expired.find_each(&:purge_sensitive_data!)
    PrivacyRequest.metadata_expired.find_each(&:destroy!)
  end
end
