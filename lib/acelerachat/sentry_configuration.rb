require 'uri'
require_relative '../acelerachat'

class Acelerachat::SentryConfiguration
  DEFAULT_TRANSACTION_SAMPLE_RATE = 0.05
  SHA_PATTERN = /\A[0-9a-f]{40}\z/

  def initialize(env: ENV, rails_environment: Rails.env.to_s, release: defined?(GIT_HASH) ? GIT_HASH : nil)
    @env = env
    @rails_environment = rails_environment
    @release = release
  end

  def enabled?
    backend_dsn.present?
  end

  def backend_options
    {
      dsn: backend_dsn,
      environment: environment,
      release: release,
      traces_sample_rate: traces_sample_rate
    }
  end

  def frontend_options
    return nil unless enabled?

    {
      dsn: frontend_dsn,
      environment: environment,
      release: release,
      tracesSampleRate: traces_sample_rate,
      sendDefaultPii: false
    }
  end

  def preflight!
    errors = preflight_errors
    raise ArgumentError, errors.join('; ') if errors.any?

    {
      enabled: true,
      environment: environment,
      release: release,
      backend_host: parsed_dsn(backend_dsn)&.host,
      frontend_host: parsed_dsn(frontend_dsn)&.host,
      traces_sample_rate: traces_sample_rate,
      send_default_pii: false
    }
  end

  private

  def preflight_errors
    required_dsn_errors +
      configured_dsn_errors +
      production_errors +
      privacy_errors +
      sample_rate_errors
  end

  def required_dsn_errors
    backend_dsn.blank? ? ['SENTRY_DSN is required'] : []
  end

  def configured_dsn_errors
    errors = []
    errors.concat(dsn_errors('SENTRY_DSN', backend_dsn)) if backend_dsn.present?
    errors.concat(dsn_errors('SENTRY_FRONTEND_DSN', frontend_dsn)) if frontend_dsn.present?
    errors
  end

  def production_errors
    return [] unless @rails_environment == 'production'

    errors = []
    errors << 'Sentry environment must be production' unless environment == 'production'
    errors << 'Sentry release must be a full commit SHA' unless release.match?(SHA_PATTERN)
    errors
  end

  def privacy_errors
    pii_requested? ? ['Sentry PII collection cannot be enabled'] : []
  end

  def backend_dsn
    @env.fetch('SENTRY_DSN', '').strip
  end

  def frontend_dsn
    @env.fetch('SENTRY_FRONTEND_DSN', '').strip.presence || backend_dsn
  end

  def environment
    @env.fetch('SENTRY_ENVIRONMENT', @rails_environment).strip
  end

  def release
    @env.fetch('SENTRY_RELEASE', '').strip.presence || @release.to_s.strip
  end

  def traces_sample_rate
    explicit_rate = @env.fetch('SENTRY_TRACES_SAMPLE_RATE', '').strip
    return Float(explicit_rate) if explicit_rate.present?
    return DEFAULT_TRANSACTION_SAMPLE_RATE if boolean_value('ENABLE_SENTRY_TRANSACTIONS')

    0.0
  rescue ArgumentError, TypeError
    Float::NAN
  end

  def sample_rate_errors
    rate = traces_sample_rate
    return [] if rate.finite? && rate.between?(0.0, 1.0)

    ['SENTRY_TRACES_SAMPLE_RATE must be between 0.0 and 1.0']
  end

  def pii_requested?
    boolean_value('SENTRY_SEND_DEFAULT_PII') || @env.fetch('DISABLE_SENTRY_PII', '').strip.casecmp('false').zero?
  end

  def boolean_value(key)
    ActiveModel::Type::Boolean.new.cast(@env.fetch(key, false))
  end

  def dsn_errors(name, value)
    uri = parsed_dsn(value)
    return ["#{name} must be a valid HTTPS Sentry DSN"] unless uri

    dsn_authority_errors(name, uri) + dsn_path_errors(name, uri)
  end

  def dsn_authority_errors(name, uri)
    [
      ("#{name} must use HTTPS" unless uri.scheme == 'https'),
      ("#{name} must include a public key" if uri.user.blank?),
      ("#{name} must not embed a secret key" if uri.password.present?),
      ("#{name} must include an ingestion host" if uri.host.blank?)
    ].compact
  end

  def dsn_path_errors(name, uri)
    [
      ("#{name} must include a project identifier" if uri.path.to_s.split('/').reject(&:blank?).empty?),
      ("#{name} must not include query parameters or fragments" if uri.query.present? || uri.fragment.present?)
    ].compact
  end

  def parsed_dsn(value)
    URI.parse(value)
  rescue URI::InvalidURIError
    nil
  end
end
