require 'rails_helper'

RSpec.describe 'WhatsApp Evolution Provisionings API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:administrator) { create(:user, account: account, role: :administrator) }

  describe 'POST /api/v1/accounts/:account_id/whatsapp/evolution_provisionings' do
    it 'rejects non-administrators' do
      post "/api/v1/accounts/#{account.id}/whatsapp/evolution_provisionings",
           params: { inbox_name: 'Sales WhatsApp' },
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns only public provisioning state to administrators' do
      provisioning = build(:whatsapp_evolution_provisioning, account: account, public_id: 'public-id')
      result = Whatsapp::Evolution::ProvisioningService::Result.new(
        provisioning: provisioning,
        qr_code: 'qr-data'
      )
      service = instance_double(Whatsapp::Evolution::ProvisioningService, perform: result)
      allow(Whatsapp::Evolution::ProvisioningService).to receive(:new).and_return(service)

      post "/api/v1/accounts/#{account.id}/whatsapp/evolution_provisionings",
           params: { inbox_name: 'Sales WhatsApp' },
           headers: administrator.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include(
        'id' => 'public-id',
        'status' => 'waiting_qr',
        'qr_code' => 'qr-data'
      )
      expect(response.parsed_body).not_to include('instance_token', 'webhook_secret', 'instance_name')
    end
  end
end
