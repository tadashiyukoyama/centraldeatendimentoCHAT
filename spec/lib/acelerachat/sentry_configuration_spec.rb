require 'rails_helper'

RSpec.describe Acelerachat::SentryConfiguration do
  let(:dsn) { 'https://public-key@errors.example.com/123' }
  let(:env) do
    {
      'SENTRY_DSN' => dsn,
      'SENTRY_FRONTEND_DSN' => 'https://browser-key@browser-errors.example.com/456',
      'SENTRY_ENVIRONMENT' => 'production',
      'SENTRY_TRACES_SAMPLE_RATE' => '0.05',
      'SENTRY_SEND_DEFAULT_PII' => 'false'
    }
  end
  let(:release) { 'a' * 40 }

  it 'returns privacy-safe backend and frontend configuration tied to the release SHA' do
    configuration = described_class.new(env: env, rails_environment: 'production', release: release)

    expect(configuration.backend_options).to include(
      dsn: dsn,
      environment: 'production',
      release: release,
      traces_sample_rate: 0.05
    )
    expect(configuration.frontend_options).to include(
      dsn: env.fetch('SENTRY_FRONTEND_DSN'),
      release: release,
      tracesSampleRate: 0.05,
      sendDefaultPii: false
    )
    expect(configuration.preflight!).to include(
      enabled: true,
      release: release,
      send_default_pii: false,
      backend_host: 'errors.example.com',
      frontend_host: 'browser-errors.example.com'
    )
  end

  it 'uses zero transaction sampling unless it is explicitly enabled' do
    env.delete('SENTRY_TRACES_SAMPLE_RATE')

    expect(described_class.new(env: env, release: release).backend_options[:traces_sample_rate]).to eq(0.0)
  end

  it 'rejects a non-HTTPS DSN' do
    env['SENTRY_DSN'] = 'http://public-key@errors.example.com/123'

    expect do
      described_class.new(env: env, rails_environment: 'production', release: release).preflight!
    end.to raise_error(ArgumentError, /must use HTTPS/)
  end

  it 'rejects DSNs that embed secrets or untrusted parameters' do
    env['SENTRY_DSN'] = 'https://public-key:secret@errors.example.com/123?token=secret'

    expect do
      described_class.new(env: env, rails_environment: 'production', release: release).preflight!
    end.to raise_error(ArgumentError, /must not embed a secret key.*must not include query parameters/)
  end

  it 'rejects attempts to enable PII collection' do
    env['SENTRY_SEND_DEFAULT_PII'] = 'true'

    expect do
      described_class.new(env: env, rails_environment: 'production', release: release).preflight!
    end.to raise_error(ArgumentError, /PII collection cannot be enabled/)
  end

  it 'requires a full release SHA in production' do
    expect do
      described_class.new(env: env, rails_environment: 'production', release: 'unknown').preflight!
    end.to raise_error(ArgumentError, /full commit SHA/)
  end
end
