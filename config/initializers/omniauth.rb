# OmniAuth configuration
# Sets the full host URL for callbacks and proper redirect handling
OmniAuth.config.full_host = ENV.fetch('FRONTEND_URL', 'http://localhost:3000')

google_client_id = ENV.fetch('GOOGLE_OAUTH_CLIENT_ID', '').strip
google_client_secret = ENV.fetch('GOOGLE_OAUTH_CLIENT_SECRET', '').strip
google_oauth_allowed = ENV.fetch('PUBLIC_BRAND_PROFILE', '').strip != 'acelerachat'

if google_oauth_allowed && google_client_id.present? && google_client_secret.present?
  Rails.application.config.middleware.use OmniAuth::Builder do
    provider :google_oauth2, google_client_id, google_client_secret, {
      provider_ignores_state: true
    }
  end
end
