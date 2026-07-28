require 'resolv'
require 'timeout'

class Acelerachat::EmailDomainDnsPreflight
  def initialize(domain:, selector:, resolver: Resolv::DNS)
    @domain = domain
    @selector = selector
    @resolver = resolver
  end

  def call
    errors = @resolver.open { |dns| validation_errors(dns) }
    raise ArgumentError, errors.join('; ') if errors.any?

    true
  rescue Resolv::ResolvError, SocketError, SystemCallError, Timeout::Error => e
    raise ArgumentError, "DNS preflight failed (#{e.class.name})"
  end

  private

  def validation_errors(dns)
    errors = []
    errors << "Missing MX for #{@domain}" if dns.getresources(@domain, Resolv::DNS::Resource::IN::MX).empty?
    errors << "Missing SPF for #{@domain}" unless txt_record_starts_with?(dns, @domain, 'v=spf1')
    errors << "Missing DMARC for #{@domain}" unless txt_record_starts_with?(dns, "_dmarc.#{@domain}", 'v=dmarc1')
    errors << "Missing DKIM for selector #{@selector}" unless dkim_record_present?(dns)
    errors
  end

  def dkim_record_present?(dns)
    name = "#{@selector}._domainkey.#{@domain}"
    txt_record_includes?(dns, name, 'p=') ||
      dns.getresources(name, Resolv::DNS::Resource::IN::CNAME).any?
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
