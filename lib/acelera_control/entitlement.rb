# frozen_string_literal: true

require 'base64'
require 'openssl'
require 'time'

# Verifies and normalizes the signed response returned by Acelera Control.
class AceleraControl::Entitlement
  PLAN_MAPPING = {
    'community' => 'community',
    'premium' => 'premium',
    'enterprise' => 'enterprise',
    'pro' => 'enterprise'
  }.freeze
  SUPPORTED_STATUSES = %w[active trialing past_due canceled suspended].freeze

  def initialize(body:, verification_key:, expected_instance_id:)
    @body = body
    @verification_key = verification_key
    @expected_instance_id = expected_instance_id
  end

  def to_h
    raw_payload, signature = decode_envelope
    raise AceleraControl::InvalidEntitlementError unless valid_signature?(raw_payload, signature)

    payload = JSON.parse(raw_payload)
    raise AceleraControl::InvalidEntitlementError unless payload.is_a?(Hash)

    validate_instance!(payload)
    normalize(payload)
  end

  private

  attr_reader :body, :verification_key, :expected_instance_id

  def decode_envelope
    envelope = JSON.parse(body)
    [
      Base64.strict_decode64(envelope.fetch('payload')),
      Base64.strict_decode64(envelope.fetch('signature'))
    ]
  end

  def valid_signature?(payload, signature)
    digest = eddsa_key? ? nil : OpenSSL::Digest.new('SHA256')
    verification_key.verify(digest, signature, payload)
  end

  def eddsa_key?
    verification_key.respond_to?(:oid) && %w[ED25519 ED448].include?(verification_key.oid)
  end

  def validate_instance!(payload)
    return if payload.fetch('instance_id') == expected_instance_id

    raise AceleraControl::InvalidEntitlementError
  end

  def normalize(payload)
    plan = normalized_plan(payload)
    seat_limit = normalized_seat_limit(payload)
    status = normalized_status(payload)
    expires_at, grace_until = validity_period(payload)
    validity = { expires_at: expires_at, grace_until: grace_until }

    normalized_attributes(payload, plan: plan, seat_limit: seat_limit, status: status, validity: validity)
      .merge(normalized_support(payload['support']))
  end

  def normalized_plan(payload)
    PLAN_MAPPING.fetch(payload.fetch('plan_code').to_s)
  rescue KeyError
    raise AceleraControl::InvalidEntitlementError
  end

  def normalized_seat_limit(payload)
    value = Integer(payload.fetch('seat_limit'))
    raise AceleraControl::InvalidEntitlementError if value.negative?

    value
  rescue ArgumentError, TypeError
    raise AceleraControl::InvalidEntitlementError
  end

  def normalized_status(payload)
    status = payload.fetch('status').to_s
    raise AceleraControl::InvalidEntitlementError unless SUPPORTED_STATUSES.include?(status)

    status
  end

  def validity_period(payload)
    expires_at_value = payload.fetch('expires_at')
    grace_until_value = payload.fetch('grace_until', expires_at_value)
    raise AceleraControl::InvalidEntitlementError unless expires_at_value.is_a?(String) && grace_until_value.is_a?(String)

    expires_at = Time.iso8601(expires_at_value)
    grace_until = Time.iso8601(grace_until_value)
    raise AceleraControl::InvalidEntitlementError if grace_until < expires_at || grace_until.past?

    [expires_at, grace_until]
  rescue ArgumentError, TypeError, KeyError
    raise AceleraControl::InvalidEntitlementError
  end

  def normalized_attributes(payload, plan:, seat_limit:, status:, validity:)
    {
      'plan' => plan,
      'plan_quantity' => seat_limit,
      'version' => payload.dig('latest_release', 'version'),
      'acelera_release_sha' => payload.dig('latest_release', 'sha'),
      'acelera_entitlements' => normalized_features(payload['features']),
      'acelera_entitlement_status' => status,
      'acelera_entitlement_expires_at' => validity[:expires_at].iso8601,
      'acelera_entitlement_grace_until' => validity[:grace_until].iso8601
    }.compact
  end

  def normalized_features(features)
    Array(features).filter_map do |feature|
      value = feature.to_s.strip
      value if value.match?(/\A[a-z0-9_:-]{1,80}\z/)
    end.uniq.sort
  end

  def normalized_support(support)
    return {} unless support.is_a?(Hash)

    support_url = AceleraControl.safe_external_url(support['base_url'])
    return {} if support_url.blank?

    {
      'chatwoot_support_website_token' => support['website_token'].presence,
      'chatwoot_support_identifier_hash' => support['identifier_hash'].presence,
      'chatwoot_support_script_url' => support_url
    }.compact
  end
end
