require 'rails_helper'

RSpec.describe ApplicationMailer do
  it 'turns an internal brand asset path into a first-party HTTPS email URL' do
    allow(GlobalConfig).to receive(:get).and_return(
      {
        'BRAND_NAME' => 'AceleraChat',
        'BRAND_URL' => 'https://atendimento.meugerenciador.pro',
        'LOGO' => '/brand-assets/acelerachat/logo.svg',
        'MAILER_SUPPORT_EMAIL' => 'suporte@meugerenciador.pro'
      }.with_indifferent_access
    )

    with_modified_env FRONTEND_URL: 'https://not-used.example' do
      config = described_class.new.send(:mailer_global_config)

      expect(config['LOGO']).to eq('https://atendimento.meugerenciador.pro/brand-assets/acelerachat/logo.svg')
      expect(config.values.join).not_to match(/chatwoot\.com|chatwoot\.help|chwt\.app/i)
    end
  end
end
