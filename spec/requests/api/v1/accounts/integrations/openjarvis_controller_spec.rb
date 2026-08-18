require 'rails_helper'

RSpec.describe 'OpenJarvis integration settings', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:service_user) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:inbox, account: account) }
  let(:path) { "/api/v1/accounts/#{account.id}/integrations/openjarvis" }
  let(:settings) do
    {
      endpoint_url: 'https://openjarvis.example.com/webhooks/acelerachat',
      service_user_id: service_user.id,
      allowed_inbox_ids: [inbox.id],
      scopes: Openjarvis::Configuration::DEFAULT_SCOPES,
      subscriptions: Openjarvis::Configuration::DEFAULT_SUBSCRIPTIONS,
      webhooks_enabled: true
    }
  end

  it 'returns safe defaults without creating a connection' do
    get path, headers: admin.create_new_auth_token

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('configured' => false, 'status' => 'not_configured')
    expect(account.hooks.where(app_id: 'openjarvis')).to be_empty
  end

  it 'allows only administrators to configure the connection' do
    put path, params: { enabled: true, openjarvis: settings }, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'creates credentials once and omits full secrets from subsequent reads' do
    put path, params: { enabled: true, openjarvis: settings }, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('credentials', 'access_token')).to be_present
    expect(response.parsed_body.dig('credentials', 'webhook_secret')).to be_present

    get path, headers: admin.create_new_auth_token

    expect(response.parsed_body).not_to have_key('credentials')
    expect(response.parsed_body.dig('credential_metadata', 'access_token_last_four')).to be_present
  end

  it 'rotates the Bearer token with a 24-hour overlap' do
    hook = create(:integrations_hook, :openjarvis, account: account, service_user: service_user, allowed_inboxes: [inbox])
    old_token = hook.access_token

    post "#{path}/rotate_access_token", headers: admin.create_new_auth_token

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('credential', 'value')).not_to eq(old_token)
    hook.reload
    expect(hook.access_token).not_to eq(old_token)
    expect(hook.previous_access_token).to eq(old_token)
    expect(hook.previous_access_token_expires_at).to be_within(5.seconds).of(24.hours.from_now)
    expect(response.parsed_body.dig('credential', 'previous_valid_until')).to be_present
  end

  it 'rotates the HMAC secret with a 24-hour dual-signature overlap' do
    hook = create(:integrations_hook, :openjarvis, account: account, service_user: service_user, allowed_inboxes: [inbox])
    old_secret = hook.webhook_secret

    post "#{path}/rotate_webhook_secret", headers: admin.create_new_auth_token

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('credential', 'value')).not_to eq(old_secret)
    hook.reload
    expect(hook.previous_webhook_secret).to eq(old_secret)
    expect(hook.previous_webhook_secret_expires_at).to be_within(5.seconds).of(24.hours.from_now)
    expect(hook.active_openjarvis_webhook_secrets).to eq([hook.webhook_secret, old_secret])
  end

  it 'tests the real configured endpoint through the signed client' do
    create(:integrations_hook, :openjarvis, account: account, service_user: service_user, allowed_inboxes: [inbox])
    client = instance_double(Openjarvis::WebhookClient, deliver: true)
    allow(Openjarvis::WebhookClient).to receive(:new).and_return(client)

    post "#{path}/test_connection", headers: admin.create_new_auth_token

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['status']).to eq('connected')
  end

  it 'disconnects and rotates both credentials' do
    hook = create(:integrations_hook, :openjarvis, account: account, service_user: service_user, allowed_inboxes: [inbox])
    old_credentials = [hook.access_token, hook.webhook_secret]

    delete path, headers: admin.create_new_auth_token

    expect(response).to have_http_status(:ok)
    hook.reload
    expect(hook).to be_disabled
    expect([hook.access_token, hook.webhook_secret]).not_to eq(old_credentials)
    expect(hook.settings['webhooks_enabled']).to be(false)
  end
end
