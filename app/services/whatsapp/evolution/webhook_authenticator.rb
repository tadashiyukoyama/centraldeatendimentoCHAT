class Whatsapp::Evolution::WebhookAuthenticator
  class AuthenticationError < StandardError; end

  def initialize(provisioning:, authorization_header:, payload:)
    @provisioning = provisioning
    @authorization_header = authorization_header.to_s
    @payload = payload
  end

  def verify!
    token = authorization_header.delete_prefix('Bearer ').presence
    raise AuthenticationError, 'Missing webhook bearer token' if token.blank?

    claims, = JWT.decode(
      token,
      provisioning.webhook_secret,
      true,
      algorithm: 'HS256',
      verify_iat: true,
      leeway: 30
    )
    raise AuthenticationError, 'Invalid webhook claims' unless valid_claims?(claims)
    raise AuthenticationError, 'Webhook instance mismatch' unless payload['instance'] == provisioning.instance_name

    true
  rescue JWT::DecodeError, JWT::ExpiredSignature, JWT::ImmatureSignature
    raise AuthenticationError, 'Invalid webhook signature'
  end

  private

  attr_reader :provisioning, :authorization_header, :payload

  def valid_claims?(claims)
    claims['app'] == 'evolution' &&
      claims['action'] == 'webhook' &&
      claims['iat'].present? &&
      claims['exp'].present? &&
      claims['exp'].to_i - claims['iat'].to_i <= 600
  end
end
