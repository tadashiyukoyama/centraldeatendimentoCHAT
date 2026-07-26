require 'rails_helper'

RSpec.describe 'AceleraChat authentication presentation', type: :request do
  around do |example|
    with_modified_env PUBLIC_BRAND_PROFILE: 'acelerachat', GOOGLE_OAUTH_CLIENT_ID: '', GOOGLE_OAUTH_CLIENT_SECRET: '' do
      PublicBrand.reset!
      example.run
    ensure
      PublicBrand.reset!
    end
  end

  it 'hides SSO and Google OAuth when no genuine provider is configured' do
    get '/app/login/sso'
    expect(response).to redirect_to('/app/login')

    follow_redirect!
    expect(response).to have_http_status(:ok)
    expect(response.body).to match(%r{<title>\s*AceleraChat\s*</title>})
    expect(response.body).to include('allowedLoginMethods: ["email"]')
    expect(response.body).not_to include('chatwoot.com')
  end

  it 'preserves and rebrands SSO when a SAML user already exists' do
    create(:user, provider: 'saml', uid: 'saml-user@example.com', email: 'saml-user@example.com')

    get '/app/login/sso'

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('AceleraChat')
    expect(response.body).to include('allowedLoginMethods: ["email","saml"]')
  end
end
