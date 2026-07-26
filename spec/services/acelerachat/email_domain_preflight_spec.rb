require 'rails_helper'

RSpec.describe Acelerachat::EmailDomainPreflight do
  let(:env) do
    {
      'PRIVACY_CONTACT_EMAIL' => 'privacidade@meugerenciador.pro',
      'SUPPORT_CONTACT_EMAIL' => 'suporte@meugerenciador.pro',
      'MAILER_SENDER_EMAIL' => 'AceleraChat <no-reply@meugerenciador.pro>',
      'SMTP_DOMAIN' => 'meugerenciador.pro',
      'MAILER_DKIM_SELECTOR' => 'acelerachat'
    }
  end
  let(:dns) { instance_double(Resolv::DNS) }

  before do
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
    result = described_class.new(env: env).call

    expect(result).to include(domain: 'meugerenciador.pro', mx: true, spf: true, dkim: true, dmarc: true)
    expect(result.fetch(:mailboxes)).to contain_exactly(
      'privacidade@meugerenciador.pro',
      'suporte@meugerenciador.pro',
      'no-reply@meugerenciador.pro',
      'seguranca@meugerenciador.pro'
    )
  end

  it 'rejects a mailbox outside SMTP_DOMAIN before release' do
    env['SUPPORT_CONTACT_EMAIL'] = 'support@example.com'

    expect { described_class.new(env: env).call }.to raise_error(ArgumentError, /must use SMTP_DOMAIN/)
  end
end
