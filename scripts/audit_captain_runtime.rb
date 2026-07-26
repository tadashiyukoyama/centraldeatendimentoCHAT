# frozen_string_literal: true

require 'json'

scope = Captain::Assistant.all
scope = scope.where(account_id: Integer(ENV.fetch('CAPTAIN_ACCOUNT_ID'))) if ENV['CAPTAIN_ACCOUNT_ID'].present?
result = Captain::RuntimeIntegrityAudit.new(scope: scope).perform
# This is an operator CLI; machine-readable stdout is its public contract.
puts JSON.pretty_generate(result) # rubocop:disable Rails/Output
raise "Captain runtime integrity audit failed with #{result[:errors]} error(s)" if result[:errors].positive?
