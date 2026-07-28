require 'net/smtp'
require 'openssl'
require 'timeout'

class Acelerachat::SmtpConnectionPreflight
  CONNECTION_TIMEOUT = 10

  def initialize(settings:, password:, smtp_factory: Net::SMTP)
    @settings = settings
    @password = password
    @smtp_factory = smtp_factory
  end

  def call
    smtp = @smtp_factory.new(smtp_settings.fetch(:address), smtp_settings.fetch(:port))
    smtp.open_timeout = CONNECTION_TIMEOUT
    smtp.read_timeout = CONNECTION_TIMEOUT
    enable_transport!(smtp)
    authenticate!(smtp)
    true
  rescue Net::SMTPError, OpenSSL::SSL::SSLError, SocketError, IOError, SystemCallError, Timeout::Error => e
    raise ArgumentError, "SMTP connectivity/authentication preflight failed (#{e.class.name})"
  end

  private

  def smtp_settings
    @settings.fetch(:smtp)
  end

  def authenticate!(smtp)
    smtp.start(
      @settings.fetch(:domain),
      smtp_settings.fetch(:username),
      @password,
      smtp_settings.fetch(:authentication).to_sym
    ) { |_session| true }
  end

  def enable_transport!(smtp)
    context = OpenSSL::SSL::SSLContext.new
    context.verify_mode = OpenSSL::SSL::VERIFY_PEER

    if smtp_settings[:ssl] || smtp_settings[:tls]
      smtp.enable_tls(context)
    else
      smtp.enable_starttls_auto(context)
    end
  end
end
