require 'mail'
require 'resolv'

class Acelerachat::EmailDomainPreflight
  REQUIRED_CONTACTS = %w[
    PRIVACY_CONTACT_EMAIL
    SUPPORT_CONTACT_EMAIL
  ].freeze

  def initialize(env: ENV)
    @env = env
  end

  def call
    settings = preflight_settings
    errors = preflight_errors(settings)
    raise ArgumentError, errors.join('; ') if errors.any?

    success_result(settings)
  end

  private

  def preflight_settings
    {
      addresses: required_addresses,
      domain: @env.fetch('SMTP_DOMAIN', '').strip.downcase.delete_suffix('.'),
      selector: @env.fetch('MAILER_DKIM_SELECTOR', '').strip.downcase
    }
  end

  def preflight_errors(settings)
    configuration_errors(settings[:domain], settings[:selector]) +
      mailbox_domain_errors(settings[:addresses], settings[:domain]) +
      dns_preflight_errors(settings[:domain], settings[:selector])
  end

  def configuration_errors(domain, selector)
    errors = []
    errors << 'SMTP_DOMAIN is required' if domain.blank?
    errors << 'MAILER_DKIM_SELECTOR is required' if selector.blank?
    errors << 'MAILER_DKIM_SELECTOR has an invalid format' unless selector.blank? || selector.match?(/\A[a-z0-9_-]+\z/)
    errors
  end

  def mailbox_domain_errors(addresses, domain)
    matching = domain.present? && addresses.all? { |address| normalized_domain(address) == domain }
    matching ? [] : ['All public mailboxes and MAILER_SENDER_EMAIL must use SMTP_DOMAIN']
  end

  def normalized_domain(address)
    address.domain.to_s.downcase.delete_suffix('.')
  end

  def dns_preflight_errors(domain, selector)
    return [] unless domain.present? && selector.present?

    dns_errors(domain, selector)
  end

  def success_result(settings)
    {
      domain: settings[:domain],
      mailboxes: settings[:addresses].map(&:address),
      spf: true,
      dkim: true,
      dmarc: true,
      mx: true
    }
  end

  def required_addresses
    values = REQUIRED_CONTACTS.map { |key| @env.fetch(key, '') }
    values << @env.fetch('MAILER_SENDER_EMAIL', '')
    values << 'seguranca@meugerenciador.pro'
    values.map do |value|
      address = Mail::Address.new(value)
      raise ArgumentError, "Invalid required mailbox: #{value.inspect}" if address.address.blank?
      raise ArgumentError, "Invalid required mailbox: #{value.inspect}" unless address.domain

      address
    end
  rescue Mail::Field::ParseError, Mail::Field::IncompleteParseError
    raise ArgumentError, 'A required AceleraChat mailbox is invalid'
  end

  def dns_errors(domain, selector)
    Resolv::DNS.open do |dns|
      validate_dns_records(dns, domain, selector)
    end
  rescue Resolv::ResolvError => e
    ["DNS preflight failed: #{e.message}"]
  end

  def validate_dns_records(dns, domain, selector)
    errors = []
    errors << "Missing MX for #{domain}" if dns.getresources(domain, Resolv::DNS::Resource::IN::MX).empty?
    errors << "Missing SPF for #{domain}" unless txt_record_starts_with?(dns, domain, 'v=spf1')
    errors << "Missing DMARC for #{domain}" unless txt_record_starts_with?(dns, "_dmarc.#{domain}", 'v=dmarc1')
    errors << "Missing DKIM for selector #{selector}" unless txt_record_includes?(dns, "#{selector}._domainkey.#{domain}", 'p=')
    errors
  end

  def txt_record_starts_with?(dns, name, marker)
    txt_values(dns, name).any? { |value| value.downcase.start_with?(marker) }
  end

  def txt_record_includes?(dns, name, marker)
    txt_values(dns, name).any? { |value| value.downcase.include?(marker) }
  end

  def txt_values(dns, name)
    dns.getresources(name, Resolv::DNS::Resource::IN::TXT).map { |record| record.strings.join }
  end
end
