require Rails.root.join('lib/acelerachat/sentry_configuration')
require Rails.root.join('lib/acelerachat/sentry_event_scrubber')

sentry_configuration = Acelerachat::SentryConfiguration.new

if sentry_configuration.enabled?
  options = sentry_configuration.backend_options

  Sentry.init do |config|
    config.dsn = options[:dsn]
    config.enabled_environments = %w[staging production]
    config.environment = options[:environment]
    config.release = options[:release]

    config.traces_sample_rate = options[:traces_sample_rate]

    config.excluded_exceptions += ['Rack::Timeout::RequestTimeoutException', 'MutexApplicationJob::LockAcquisitionError']

    # AceleraChat handles customer conversations and contact data. Error
    # monitoring must never include request bodies, cookies, query strings,
    # user IPs, or local variables.
    config.send_default_pii = false
    config.include_local_variables = false
    config.propagate_traces = false
    config.max_breadcrumbs = 30
    config.before_breadcrumb = lambda do |breadcrumb, _hint|
      Acelerachat::SentryEventScrubber.scrub_breadcrumb(breadcrumb)
    end
    config.before_send = lambda do |event, _hint|
      Acelerachat::SentryEventScrubber.scrub_event(event)
    end
    config.before_send_transaction = lambda do |event, _hint|
      Acelerachat::SentryEventScrubber.scrub_event(event)
    end
  end
end
