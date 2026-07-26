require 'rails_helper'

RSpec.describe PrivacyRequestMailer do
  let(:privacy_request) { PrivacyRequest.new(email: 'titular@example.com', request_type: :access).prepare_submission! }

  it 'uses only AceleraChat branding and first-party links' do
    privacy_request.save!
    with_modified_env PUBLIC_BRAND_PROFILE: 'acelerachat', FRONTEND_URL: 'https://not-used.example' do
      PublicBrand.reset!
      mail = described_class.with(
        privacy_request: privacy_request,
        verification_token: privacy_request.raw_verification_token,
        status_token: privacy_request.raw_status_token,
        locale: 'pt_BR'
      ).verification

      rendered = mail.body.encoded
      expect(mail.subject).to include('AceleraChat')
      expect(rendered).to include('atendimento.meugerenciador.pro', 'AceleraChat')
      expect(rendered).not_to match(/Chatwoot|chatwoot\.com|chatwoot\.help|chwt\.app/i)
    end
  ensure
    PublicBrand.reset!
  end
end
