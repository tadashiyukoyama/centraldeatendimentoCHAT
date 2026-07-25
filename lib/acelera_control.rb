# frozen_string_literal: true

require 'json'
require 'openssl'
require 'time'
require 'uri'

# Opt-in client for the AceleraChat control plane.
#
# The client deliberately stays disabled until URL, token and verification key
# are configured. Entitlements are accepted only from a signed envelope, so a
# network failure or an untrusted response can never overwrite the local plan.
module AceleraControl
  class InvalidEntitlementError < StandardError; end

  HEARTBEAT_PATH = '/v1/instances/heartbeat'
  OPEN_TIMEOUT = 3
  READ_TIMEOUT = 5
  NETWORK_ERRORS = (ExceptionList::REST_CLIENT_EXCEPTIONS + [
    Errno::ECONNRESET,
    Errno::EHOSTUNREACH,
    Errno::ENETUNREACH,
    Errno::ETIMEDOUT,
    OpenSSL::SSL::SSLError
  ]).uniq.freeze
  HEARTBEAT_ERRORS = (NETWORK_ERRORS + [
    JSON::ParserError,
    KeyError,
    ArgumentError,
    OpenSSL::PKey::PKeyError,
    InvalidEntitlementError
  ]).freeze

  class << self
    def managed?
      boolean_env?('ACELERA_CONTROL_ENABLED')
    end

    def enabled?
      return false unless managed?

      base_url.present? && api_token.present? && verification_key.present?
    rescue OpenSSL::PKey::PKeyError, ArgumentError
      log_rejection('invalid configuration')
      false
    end

    def base_url
      url = safe_external_url(ENV.fetch('ACELERA_CONTROL_URL', nil))
      return if url.blank?

      uri = URI.parse(url)
      return if uri.query.present? || uri.fragment.present?

      url.delete_suffix('/')
    rescue URI::InvalidURIError
      nil
    end

    def heartbeat_url
      return if base_url.blank?

      "#{base_url}#{HEARTBEAT_PATH}"
    end

    def billing_url
      safe_external_url(ENV.fetch('ACELERA_BILLING_PORTAL_URL', nil))
    end

    def entitlement_active?
      grace_until = InstallationConfig.find_by(name: 'ACELERA_CONTROL_GRACE_UNTIL')&.value
      grace_until.present? && Time.iso8601(grace_until.to_s).future?
    rescue ArgumentError
      false
    end

    def heartbeat(instance_config)
      return {} unless enabled?

      response = perform_heartbeat_request(instance_config)
      Entitlement.new(
        body: response.to_s,
        verification_key: verification_key,
        expected_instance_id: instance_config.fetch(:instance_id)
      ).to_h
    rescue *HEARTBEAT_ERRORS => e
      log_rejection(e.class.name)
      {}
    end

    def safe_external_url(value)
      UrlPolicy.call(value)
    end

    private

    def api_token
      ENV.fetch('ACELERA_CONTROL_TOKEN', '').strip
    end

    def verification_key
      value = ENV.fetch('ACELERA_CONTROL_PUBLIC_KEY', '').gsub('\\n', "\n").strip
      return if value.blank?

      OpenSSL::PKey.read(value)
    end

    def request_headers
      {
        content_type: :json,
        accept: :json,
        authorization: "Bearer #{api_token}",
        user_agent: "AceleraChat/#{Chatwoot.config[:version]}"
      }
    end

    def perform_heartbeat_request(instance_config)
      RestClient::Request.execute(
        method: :post,
        url: heartbeat_url,
        payload: instance_config.to_json,
        headers: request_headers,
        open_timeout: OPEN_TIMEOUT,
        read_timeout: READ_TIMEOUT
      )
    end

    def boolean_env?(key)
      ActiveModel::Type::Boolean.new.cast(ENV.fetch(key, false))
    end

    def log_rejection(reason)
      Rails.logger.warn("[AceleraControl] response ignored (#{reason})")
    end
  end
end
