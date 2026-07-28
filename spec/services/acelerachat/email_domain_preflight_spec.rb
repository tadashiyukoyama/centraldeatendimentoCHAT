require 'rails_helper'

RSpec.describe Acelerachat::EmailDomainPreflight do
  let(:env) do
    {
      'PRIVACY_CONTACT_EMAIL' => 'privacidade@meugerenciador.pro',
      'SUPPORT_CONTACT_EMAIL' => 'suporte@meugerenciador.pro',
      'MAILER_SENDER_EMAIL' => 'AceleraChat <no-reply@meugerenciador.pro>',
      'SMTP_DOMAIN' => 'meugerenciador.pro',
      'MAILER_DKIM_SELECTOR' => 'acelerachat',
      'SMTP_ADDRESS' => 'smtp.hostinger.com',
      'SMTP_PORT' => '465',
      'SMTP_USERNAME' => 'no-reply@meugerenciador.pro',
      'SMTP_PASSWORD' => 'test-only-secret',
      'SMTP_AUTHENTICATION' => 'login',
      'SMTP_ENABLE_STARTTLS_AUTO' => 'false',
      'SMTP_SSL' => 'true',
      'SMTP_OPENSSL_VERIFY_MODE' => 'peer'
    }
  end
  let(:dns) { instance_double(Resolv::DNS) }
  let(:smtp) { instance_double(Net::SMTP) }
  let(:smtp_factory) { class_double(Net::SMTP, new: smtp) }

  before do
    allow(smtp).to receive(:open_timeout=)
    allow(smtp).to receive(:read_timeout=)
    allow(smtp).to receive(:enable_tls)
    allow(smtp).to receive(:enable_starttls_auto)
    allow(smtp).to receive(:start).and_yield
    allow(Resolv::DNS).to receive(:open).and_yield(dns)
    allow(dns).to receive(:getresources).and_return([])
    allow(dns).to receive(:getresources)
      .with('meugerenciador.pro', Resolv::DNS::Resource::IN::MX)
      .and_return([instance_double(Resolv::DNS::Resource::IN::MX)])
    allow(dns).to receive(:getresources)
      .with('meugerenciador.pro', Resolv::DNS::Resource::IN::TXT)
      .and_return([instance_double(Resolv::DNS::Resource::IN::TXT, strings: ['v=spf1 include:mail.example -all'])])
    allow(dns).to receive(:getresources)
      .with('_dmarc.meugerenciador.pro', Resolv::DNS::Resource::IN::TXT)
      .and_return([instance_double(Resolv::DNS::Resource::IN::TXT, strings: ['v=DMARC1; p=reject'])])
    allow(dns).to receive(:getresources)
      .with('acelerachat._domainkey.meugerenciador.pro', Resolv::DNS::Resource::IN::TXT)
      .and_return([instance_double(Resolv::DNS::Resource::IN::TXT, strings: ['v=DKIM1; p=public-key'])])
  end

  it 'accepts first-party mailboxes only after MX, SPF, DKIM, and DMARC pass' do
    result = described_class.new(env: env, smtp_factory: smtp_factory).call

    expect(result).to include(domain: 'meugerenciador.pro', mx: true, spf: true, dkim: true, dmarc: true)
    expect(result.fetch(:smtp)).to eq(
      address: 'smtp.hostinger.com',
      port: 465,
      authentication: 'login',
      authenticated: true,
      transport_security: 'ssl',
      verify_mode: 'peer'
    )
    expect(smtp).to have_received(:enable_tls)
    expect(smtp).to have_received(:start).with(
      'meugerenciador.pro',
      'no-reply@meugerenciador.pro',
      'test-only-secret',
      :login
    )
    expect(result.fetch(:mailboxes)).to contain_exactly(
      'privacidade@meugerenciador.pro',
      'suporte@meugerenciador.pro',
      'no-reply@meugerenciador.pro',
      'seguranca@meugerenciador.pro'
    )
  end

  it 'rejects a mailbox outside SMTP_DOMAIN before release' do
    env['SUPPORT_CONTACT_EMAIL'] = 'support@example.com'

    expect do
      described_class.new(env: env, smtp_factory: smtp_factory).call
    end.to raise_error(ArgumentError, /must use SMTP_DOMAIN/)
  end

  it 'rejects missing SMTP credentials before querying DNS' do
    env['SMTP_PASSWORD'] = ''

    expect do
      described_class.new(env: env, smtp_factory: smtp_factory).call
    end.to raise_error(ArgumentError, /SMTP_PASSWORD is required/)
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

  it 'accepts DKIM published through a provider CNAME' do
    dkim_name = 'acelerachat._domainkey.meugerenciador.pro'
    allow(dns).to receive(:getresources)
      .with(dkim_name, Resolv::DNS::Resource::IN::TXT)
      .and_return([])
    allow(dns).to receive(:getresources)
      .with(dkim_name, Resolv::DNS::Resource::IN::CNAME)
      .and_return([instance_double(Resolv::DNS::Resource::IN::CNAME)])

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
