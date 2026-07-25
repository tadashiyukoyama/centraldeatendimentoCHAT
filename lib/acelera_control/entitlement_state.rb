# frozen_string_literal: true

require 'time'

# Reads only previously verified entitlement state persisted by the sync job.
class AceleraControl::EntitlementState
  ACTIVE_STATUSES = %w[active trialing past_due].freeze

  def self.active?
    status = InstallationConfig.find_by(name: 'ACELERA_CONTROL_STATUS')&.value.to_s
    return false unless ACTIVE_STATUSES.include?(status)

    grace_until = InstallationConfig.find_by(name: 'ACELERA_CONTROL_GRACE_UNTIL')&.value
    grace_until.present? && Time.iso8601(grace_until.to_s).future?
  rescue ArgumentError
    false
  end
end
