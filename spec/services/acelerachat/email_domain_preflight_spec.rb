require 'rails_helper'

RSpec.describe Acelerachat::EmailDomainPreflight do
  let(:env) do
    {
      'PRIVACY_CONTACT_EMAIL' => 'bellartecomercial@gmail.com',
      'SUPPORT_CONTACT_EMAIL' => 'suporte@aifoodmanager.pro',
      'MAILER_SENDER_EMAIL' => 'AceleraChat <suporte@aifoodmanager.pro>',
      'SMTP_DOMAIN' => 'aifoodmanager.pro',
      'MAILER_DKIM_SELECTORS' => 'hostingermail-a,hostingermail-b,hostingermail-c',
      'SMTP_ADDRESS' => 'smtp.hostinger.com',
      'SMTP_PORT' => '465',
      'SMTP_USERNAME' => 'suporte@aifoodmanager.pro',
      'SMTP_PASSWORD' => 'test-only-secret',
      'SMTP_AUTHENTICATION' => 'login',
      'SMTP_ENABLE_STARTTLS_AUTO' => 'false',
      'SMTP_SSL' => 'true',
      'SMTP_OPENSSL_VERIFY_MODE' => 'peer',
      'ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY' => 'primary-test-key',
      'ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY' => 'deterministic-test-key',
      'ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT' => 'test-key-derivation-salt'
    }
  end
  let(:dns) { instance_double(Resolv::DNS) }
  let(:smtp) { instance_double(Net::SMTP) }
  let(:smtp_factory) { class_double(Net::SMTP, new: smtp) }
  let(:tls_contexts) { [] }

  before do
    allow(smtp).to receive(:open_timeout=)
    allow(smtp).to receive(:read_timeout=)
    allow(smtp).to receive(:enable_tls) { |context| tls_contexts << context }
    allow(smtp).to receive(:enable_starttls_auto) { |context| tls_contexts << context }
    allow(smtp).to receive(:start).and_yield
    allow(Resolv::DNS).to receive(:open).and_yield(dns)
    allow(dns).to receive(:getresources).and_return([])
    allow(dns).to receive(:getresources)
      .with('aifoodmanager.pro', Resolv::DNS::Resource::IN::MX)
      .and_return([instance_double(Resolv::DNS::Resource::IN::MX)])
    allow(dns).to receive(:getresources)
      .with('aifoodmanager.pro', Resolv::DNS::Resource::IN::TXT)
      .and_return([instance_double(Resolv::DNS::Resource::IN::TXT, strings: ['v=spf1 include:mail.example -all'])])
    allow(dns).to receive(:getresources)
      .with('_dmarc.aifoodmanager.pro', Resolv::DNS::Resource::IN::TXT)
      .and_return([instance_double(Resolv::DNS::Resource::IN::TXT, strings: ['v=DMARC1; p=reject'])])
    %w[hostingermail-a hostingermail-b hostingermail-c].each do |selector|
      allow(dns).to receive(:getresources)
        .with("#{selector}._domainkey.aifoodmanager.pro", Resolv::DNS::Resource::IN::CNAME)
        .and_return([instance_double(Resolv::DNS::Resource::IN::CNAME)])
    end
  end

  it 'accepts the sender after MX, SPF, every DKIM selector, DMARC, and SMTP authentication pass' do
    result = described_class.new(env: env, smtp_factory: smtp_factory).call

    expect(result).to include(
      domain: 'aifoodmanager.pro',
      dkim_selectors: %w[hostingermail-a hostingermail-b hostingermail-c],
      mx: true,
      spf: true,
      dkim: true,
      dmarc: true,
      credential_encryption: true
    )
    expect(result.fetch(:smtp)).to eq(
      address: 'smtp.hostinger.com',
      port: 465,
      authentication: 'login',
      authenticated: true,
      transport_security: 'ssl',
      verify_mode: 'peer'
    )
    expect(smtp).to have_received(:enable_tls)
    expect(tls_contexts).to contain_exactly(
      have_attributes(
        verify_mode: OpenSSL::SSL::VERIFY_PEER,
        cert_store: an_instance_of(OpenSSL::X509::Store)
      )
    )
    expect(smtp).to have_received(:start).with(
      'aifoodmanager.pro',
      'suporte@aifoodmanager.pro',
      'test-only-secret',
      :login
    )
    expect(result.fetch(:mailboxes)).to contain_exactly(
      'bellartecomercial@gmail.com',
      'suporte@aifoodmanager.pro'
    )
  end

  it 'allows the legal privacy contact to use another valid domain' do
    env['PRIVACY_CONTACT_EMAIL'] = 'privacy@example.com'

    expect do
      described_class.new(env: env, smtp_factory: smtp_factory).call
    end.not_to raise_error
  end

  it 'rejects a sender outside SMTP_DOMAIN before release' do
    env['MAILER_SENDER_EMAIL'] = 'AceleraChat <support@example.com>'

    expect do
      described_class.new(env: env, smtp_factory: smtp_factory).call
    end.to raise_error(ArgumentError, /MAILER_SENDER_EMAIL must use SMTP_DOMAIN/)
  end

  it 'rejects missing SMTP credentials before querying DNS' do
    env['SMTP_PASSWORD'] = ''

    expect do
      described_class.new(env: env, smtp_factory: smtp_factory).call
    end.to raise_error(ArgumentError, /SMTP_PASSWORD is required/)
  end

  it 'rejects storing inbox credentials without the complete encryption key set' do
    env['ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY'] = ''

    expect do
      described_class.new(env: env, smtp_factory: smtp_factory).call
    end.to raise_error(ArgumentError, /ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY/)
  end

  it 'rejects an insecure SMTP transport' do
    env['SMTP_SSL'] = 'false'

    expect do
      described_class.new(env: env, smtp_factory: smtp_factory).call
    end.to raise_error(ArgumentError, /must enable exactly one/)
  end

  it 'rejects conflicting SMTP transports' do
    env['SMTP_ENABLE_STARTTLS_AUTO'] = 'true'

    expect do
      described_class.new(env: env, smtp_factory: smtp_factory).call
    end.to raise_error(ArgumentError, /must enable exactly one/)
  end

  it 'fails closed when any configured DKIM selector is missing' do
    dkim_name = 'hostingermail-c._domainkey.aifoodmanager.pro'
    allow(dns).to receive(:getresources)
      .with(dkim_name, Resolv::DNS::Resource::IN::CNAME)
      .and_return([])
    allow(dns).to receive(:getresources)
      .with(dkim_name, Resolv::DNS::Resource::IN::TXT)
      .and_return([])

    expect do
      described_class.new(env: env, smtp_factory: smtp_factory).call
    end.to raise_error(ArgumentError, /Missing DKIM for selector hostingermail-c/)
  end

  it 'supports the legacy singular DKIM setting during rollout' do
    env.delete('MAILER_DKIM_SELECTORS')
    env['MAILER_DKIM_SELECTOR'] = 'hostingermail-a'

    expect do
      described_class.new(env: env, smtp_factory: smtp_factory).call
    end.not_to raise_error
  end

  it 'fails closed when SMTP authentication is rejected' do
    allow(smtp).to receive(:start).and_raise(Net::SMTPAuthenticationError.new('rejected'))

    expect do
      described_class.new(env: env, smtp_factory: smtp_factory).call
    end.to raise_error(ArgumentError, %r{SMTP connectivity/authentication preflight failed})
  end
end
