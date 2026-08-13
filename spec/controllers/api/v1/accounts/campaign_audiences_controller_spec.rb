require 'rails_helper'

RSpec.describe 'Campaign audiences API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:csv_file) { Rack::Test::UploadedFile.new(Rails.root.join('spec/assets/contacts.csv'), 'text/csv') }

  describe 'POST /api/v1/accounts/:account_id/campaign_audiences' do
    it 'creates a traceable imported list for administrators' do
      post "/api/v1/accounts/#{account.id}/campaign_audiences",
           params: { name: 'August restaurant leads', import_file: csv_file },
           headers: administrator.create_new_auth_token

      expect(response).to have_http_status(:accepted)
      expect(response.parsed_body['name']).to eq('August restaurant leads')
      expect(response.parsed_body['status']).to eq('pending')
      expect(response.parsed_body['label_id']).to be_present

      data_import = account.data_imports.find(response.parsed_body['id'])
      expect(data_import).to be_campaign_audience_import
      expect(data_import.initiated_by).to eq(administrator)
      expect(data_import.import_file).to be_attached
    end

    it 'rejects non-CSV files with a recovery message' do
      invalid_file = Rack::Test::UploadedFile.new(
        Rails.root.join('spec/assets/contacts.csv'),
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        false,
        original_filename: 'contacts.xlsx'
      )

      post "/api/v1/accounts/#{account.id}/campaign_audiences",
           params: { name: 'Invalid list', import_file: invalid_file },
           headers: administrator.create_new_auth_token

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['message']).to eq('A lista deve ser um arquivo CSV.')
    end

    it 'does not allow agents to create campaign lists' do
      post "/api/v1/accounts/#{account.id}/campaign_audiences",
           params: { name: 'Private list', import_file: csv_file },
           headers: agent.create_new_auth_token

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/accounts/:account_id/campaign_audiences' do
    it 'returns only managed campaign lists from the current account' do
      managed_import = create(:data_import, account: account, name: 'Managed list')
      label = create(:label, account: account, title: "campaign_list_#{managed_import.id}")
      managed_import.update!(source_metadata: {
                               DataImport::CAMPAIGN_AUDIENCE_KIND_KEY => DataImport::CAMPAIGN_AUDIENCE_KIND,
                               DataImport::CAMPAIGN_AUDIENCE_LABEL_ID_KEY => label.id
                             })
      create(:data_import, account: account, name: 'Regular contact import')

      get "/api/v1/accounts/#{account.id}/campaign_audiences",
          headers: administrator.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck('id')).to eq([managed_import.id])
    end
  end
end
