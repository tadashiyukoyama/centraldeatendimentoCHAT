require 'mail'
require 'net/smtp'
require_relative 'email_domain_dns_preflight'
require_relative 'smtp_connection_preflight'

class Acelerachat::EmailDomainPreflight
  AUTHENTICATION_METHODS = %w[plain login cram_md5].freeze
  REQUIRED_CONTACTS = %w[
    PRIVACY_CONTACT_EMAIL
    SUPPORT_CONTACT_EMAIL
  ].freeze
  ENCRYPTION_KEYS = %w[
    ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY
    ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY
    ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT
  ].freeze

  def initialize(env: ENV, smtp_factory: Net::SMTP)
    @env = env
    @smtp_factory = smtp_factory
  end

  def call
    settings = preflight_settings
    validate_configuration!(settings)
    validate_dns!(settings)
    validate_smtp_connection!(settings)

    success_result(settings)
  end

  private

  def preflight_settings
    {
      contacts: required_contacts,
      sender: required_sender,
      domain: @env.fetch('SMTP_DOMAIN', '').strip.downcase.delete_suffix('.'),
      selectors: dkim_selectors,
      smtp: smtp_settings
    }
  end

  def validate_configuration!(settings)
    errors = configuration_errors(settings[:domain], settings[:selectors], settings[:smtp])
    errors.concat(sender_domain_errors(settings[:sender], settings[:domain]))
    raise ArgumentError, errors.join('; ') if errors.any?
  end

  def validate_dns!(settings)
    Acelerachat::EmailDomainDnsPreflight.new(
      domain: settings[:domain],
      selectors: settings[:selectors]
    ).call
  end

  def configuration_errors(domain, selectors, smtp)
    errors = []
    errors << 'SMTP_DOMAIN is required' if domain.blank?
    errors << 'MAILER_DKIM_SELECTORS is required' if selectors.empty?
    errors << 'MAILER_DKIM_SELECTORS has an invalid format' unless selectors.all? { |selector| selector.match?(/\A[a-z0-9_-]+\z/) }
    errors.concat(encryption_configuration_errors)
    errors.concat(smtp_configuration_errors(smtp, domain))
    errors
  end

  def encryption_configuration_errors
    missing = ENCRYPTION_KEYS.reject { |key| @env.fetch(key, '').present? }
    return [] if missing.empty?

    ["Email inbox credential encryption requires: #{missing.join(', ')}"]
  end

  def dkim_selectors
    configured = @env.fetch('MAILER_DKIM_SELECTORS', '').presence || @env.fetch('MAILER_DKIM_SELECTOR', '')
    configured.to_s.split(',').map { |selector| selector.strip.downcase }.reject(&:blank?).uniq
  end

  def smtp_settings
    {
      address: @env.fetch('SMTP_ADDRESS', '').strip.downcase,
      port: integer_port(@env.fetch('SMTP_PORT', '')),
      username: @env.fetch('SMTP_USERNAME', '').strip,
      password_present: @env.fetch('SMTP_PASSWORD', '').present?,
      authentication: @env.fetch('SMTP_AUTHENTICATION', '').strip.downcase,
      starttls: boolean_value('SMTP_ENABLE_STARTTLS_AUTO', true),
      ssl: boolean_value('SMTP_SSL', false),
      tls: boolean_value('SMTP_TLS', false),
      verify_mode: @env.fetch('SMTP_OPENSSL_VERIFY_MODE', 'peer').strip.downcase
    }
  end

  def integer_port(value)
    Integer(value)
  rescue ArgumentError, TypeError
    nil
  end

  def boolean_value(key, default)
    ActiveModel::Type::Boolean.new.cast(@env.fetch(key, default))
  end

  def smtp_configuration_errors(smtp, domain)
    smtp_endpoint_errors(smtp) +
      smtp_authentication_errors(smtp) +
      smtp_transport_errors(smtp) +
      smtp_username_errors(smtp[:username], domain)
  end

  def smtp_endpoint_errors(smtp)
    errors = []
    errors << 'SMTP_ADDRESS is required' if smtp[:address].blank?
    errors << 'SMTP_ADDRESS must be a hostname without scheme or path' unless valid_smtp_hostname?(smtp[:address])
    errors << 'SMTP_PORT must be between 1 and 65535' unless smtp[:port]&.between?(1, 65_535)
    errors
  end

  def smtp_authentication_errors(smtp)
    errors = []
    errors << 'SMTP_USERNAME is required' if smtp[:username].blank?
    errors << 'SMTP_PASSWORD is required' unless smtp[:password_present]
    errors << 'SMTP_AUTHENTICATION must be plain, login, or cram_md5' unless
      AUTHENTICATION_METHODS.include?(smtp[:authentication])
    errors
  end

  def smtp_transport_errors(smtp)
    errors = []
    enabled_transports = smtp.values_at(:starttls, :tls, :ssl).count(true)
    errors << 'SMTP transport must enable exactly one of STARTTLS, TLS, or SSL' unless enabled_transports == 1
    errors << 'SMTP_OPENSSL_VERIFY_MODE must be peer' unless smtp[:verify_mode] == 'peer'
    errors
  end

  def valid_smtp_hostname?(address)
    address.present? &&
      address.match?(/\A[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+\z/i)
  end

  def smtp_username_errors(username, domain)
    return [] if username.blank?

    address = Mail::Address.new(username)
    return ['SMTP_USERNAME must be a valid email address'] if address.address.blank? || address.domain.blank?
    return [] if domain.blank? || normalized_domain(address) == domain

    ['SMTP_USERNAME must use SMTP_DOMAIN']
  rescue Mail::Field::ParseError, Mail::Field::IncompleteParseError
    ['SMTP_USERNAME must be a valid email address']
  end

  def sender_domain_errors(sender, domain)
    return [] if domain.present? && normalized_domain(sender) == domain

    ['MAILER_SENDER_EMAIL must use SMTP_DOMAIN']
  end

  def normalized_domain(address)
    address.domain.to_s.downcase.delete_suffix('.')
  end

  def validate_smtp_connection!(settings)
    Acelerachat::SmtpConnectionPreflight.new(
      settings: settings,
      password: @env.fetch('SMTP_PASSWORD'),
      smtp_factory: @smtp_factory
    ).call
  end

  def success_result(settings)
    {
      domain: settings[:domain],
      mailboxes: (settings[:contacts] + [settings[:sender]]).map(&:address).uniq,
      dkim_selectors: settings[:selectors],
      smtp: {
        address: settings.dig(:smtp, :address),
        port: settings.dig(:smtp, :port),
        authentication: settings.dig(:smtp, :authentication),
        authenticated: true,
        transport_security: smtp_transport_security(settings[:smtp]),
        verify_mode: settings.dig(:smtp, :verify_mode)
      },
      spf: true,
      dkim: true,
      dmarc: true,
      mx: true,
      credential_encryption: true
    }
  end

  def smtp_transport_security(smtp)
    return 'ssl' if smtp[:ssl]
    return 'tls' if smtp[:tls]

    'starttls'
  end

  def required_contacts
    REQUIRED_CONTACTS.map { |key| parse_required_address(@env.fetch(key, ''), key) }
  end

  def required_sender
    parse_required_address(@env.fetch('MAILER_SENDER_EMAIL', ''), 'MAILER_SENDER_EMAIL')
  end

  def parse_required_address(value, key)
    address = Mail::Address.new(value)
    raise ArgumentError, "#{key} must be a valid email address" if address.address.blank? || address.domain.blank?

    address
  rescue Mail::Field::ParseError, Mail::Field::IncompleteParseError
    raise ArgumentError, "#{key} must be a valid email address"
  end
end
