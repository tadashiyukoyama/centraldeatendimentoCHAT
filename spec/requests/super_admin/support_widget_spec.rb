require 'rails_helper'

RSpec.describe 'Super Admin support widget', type: :request do
  let(:injection) { '</script><script>window.supportPwned=true</script>' }
  let(:super_admin) { create(:super_admin, name: injection) }

  before do
    create(:installation_config, name: 'CHATWOOT_SUPPORT_SCRIPT_URL', value: 'https://support.acelerachat.example')
    create(:installation_config, name: 'CHATWOOT_SUPPORT_WEBSITE_TOKEN', value: injection)
    create(:installation_config, name: 'CHATWOOT_SUPPORT_IDENTIFIER_HASH', value: 'signed-identifier')
    allow(ChatwootHub).to receive(:installation_identifier).and_return(injection)
  end

  it 'serializes support values as escaped JSON instead of executable source' do
    sign_in(super_admin, scope: :super_admin)
    get '/super_admin/users'

    support_config_json = response.body[/const supportConfig = (.+);/, 1]
    support_user_json = response.body[/const supportUser = (.+);/, 1]

    expect(response).to have_http_status(:success)
    expect(response.body).not_to include(injection)
    expect(JSON.parse(support_config_json)).to include('websiteToken' => injection)
    expect(JSON.parse(support_user_json)).to include('identifier' => injection, 'name' => injection)
  end
end
