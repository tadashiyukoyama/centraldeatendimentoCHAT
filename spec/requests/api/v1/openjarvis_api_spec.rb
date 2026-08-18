require 'rails_helper'

RSpec.describe 'OpenJarvis API', type: :request do
  let(:account) { create(:account) }
  let(:service_user) { create(:user, account: account, role: :administrator) }
  let(:allowed_inbox) { create(:inbox, account: account) }
  let(:other_inbox) { create(:inbox, account: account) }
  let(:hook) do
    create(
      :integrations_hook,
      :openjarvis,
      account: account,
      service_user: service_user,
      allowed_inboxes: [allowed_inbox]
    )
  end
  let(:headers) { { 'Authorization' => "Bearer #{hook.access_token}" } }

  describe 'authentication and catalog' do
    it 'rejects missing credentials without exposing configuration details' do
      get '/api/v1/openjarvis/catalog'

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body.dig('error', 'code')).to eq('invalid_credentials')
    end

    it 'returns the granted contract for a valid credential' do
      get '/api/v1/openjarvis/catalog', headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['granted_scopes']).to include('messages:write')
      expect(response.parsed_body['endpoints']).to include(
        hash_including('method' => 'POST', 'path' => '/api/v1/openjarvis/conversations/:conversation_id/messages')
      )
    end
  end

  describe 'authorized inbox and conversation boundaries' do
    it 'lists only configured inboxes' do
      other_inbox
      get '/api/v1/openjarvis/inboxes', headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['data'].pluck('id')).to eq([allowed_inbox.id])
    end

    it 'does not reveal conversations from another inbox' do
      hidden = create(:conversation, account: account, inbox: other_inbox)

      get "/api/v1/openjarvis/conversations/#{hidden.display_id}", headers: headers

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body.dig('error', 'code')).to eq('conversation_not_found')
    end
  end

  describe 'idempotent contact writes' do
    let(:request_headers) { headers.merge('Idempotency-Key' => 'contact-create-0001') }
    let(:payload) do
      {
        contact: {
          name: 'Restaurante Teste',
          email: 'contato@restaurante.test',
          phone_number: '+5511999999999',
          contact_type: 'lead'
        }
      }
    end

    it 'creates once and replays the same response' do
      post '/api/v1/openjarvis/contacts', params: payload, headers: request_headers, as: :json
      first_body = response.parsed_body

      expect(response).to have_http_status(:created)
      expect(response.headers['Idempotency-Replayed']).to eq('false')

      post '/api/v1/openjarvis/contacts', params: payload, headers: request_headers, as: :json

      expect(response).to have_http_status(:created)
      expect(response.headers['Idempotency-Replayed']).to eq('true')
      expect(response.parsed_body).to eq(first_body)
      expect(account.contacts.where(email: 'contato@restaurante.test').count).to eq(1)
    end

    it 'requires a valid idempotency key' do
      post '/api/v1/openjarvis/contacts', params: payload, headers: headers, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body.dig('error', 'code')).to eq('invalid_idempotency_key')
    end

    it 'rejects an unsupported contact type without creating a record' do
      payload[:contact][:contact_type] = 'prospect'

      expect do
        post '/api/v1/openjarvis/contacts',
             params: payload,
             headers: headers.merge('Idempotency-Key' => 'contact-create-invalid-type-0001'),
             as: :json
      end.not_to change(account.contacts, :count)

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body.dig('error', 'code')).to eq('invalid_contact_type')
    end
  end

  describe 'message delivery' do
    let(:conversation) { create(:conversation, account: account, inbox: allowed_inbox) }

    it 'persists an outgoing message in an authorized conversation' do
      post "/api/v1/openjarvis/conversations/#{conversation.display_id}/messages",
           params: { message: { content: 'Mensagem controlada' } },
           headers: headers.merge('Idempotency-Key' => 'message-send-0001'),
           as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig('data', 'content')).to eq('Mensagem controlada')
      expect(conversation.messages.outgoing.last.sender).to eq(service_user)
    end

    it 'rejects an invalid message cursor' do
      get "/api/v1/openjarvis/conversations/#{conversation.display_id}/messages",
          params: { before_id: 'not-an-id' },
          headers: headers

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body.dig('error', 'code')).to eq('invalid_before_id')
    end
  end

  describe 'conversation assignment boundaries' do
    let(:contact) { create(:contact, account: account) }

    before do
      create(:conversation, account: account, inbox: allowed_inbox, contact: contact)
    end

    it 'rejects a team from another account during conversation creation' do
      foreign_team = create(:team)

      expect do
        post '/api/v1/openjarvis/conversations',
             params: {
               conversation: {
                 inbox_id: allowed_inbox.id,
                 contact_id: contact.id,
                 source_id: SecureRandom.uuid,
                 team_id: foreign_team.id
               }
             },
             headers: headers.merge('Idempotency-Key' => 'conversation-create-team-boundary-0001'),
             as: :json
      end.not_to change(account.conversations, :count)

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body.dig('error', 'code')).to eq('team_not_authorized')
    end

    it 'rejects an assignee from another account during conversation creation' do
      foreign_agent = create(:user, account: create(:account), role: :agent)

      expect do
        post '/api/v1/openjarvis/conversations',
             params: {
               conversation: {
                 inbox_id: allowed_inbox.id,
                 contact_id: contact.id,
                 source_id: SecureRandom.uuid,
                 assignee_id: foreign_agent.id
               }
             },
             headers: headers.merge('Idempotency-Key' => 'conversation-create-assignee-boundary-0001'),
             as: :json
      end.not_to change(account.conversations, :count)

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body.dig('error', 'code')).to eq('assignee_not_authorized')
    end

    it 'returns created for a new authorized conversation' do
      post '/api/v1/openjarvis/conversations',
           params: {
             conversation: {
               inbox_id: allowed_inbox.id,
               contact_id: contact.id,
               source_id: SecureRandom.uuid
             }
           },
           headers: headers.merge('Idempotency-Key' => 'conversation-create-authorized-0001'),
           as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig('data', 'contact', 'id')).to eq(contact.id)
    end

    it 'applies the target team before validating the assignee under strict visibility' do
      account.enable_features!(:strict_team_conversation_visibility)
      target_team = create(:team, account: account)
      target_agent = create(:user, account: account, role: :agent)
      create(:team_member, team: target_team, user: target_agent)
      create(:inbox_member, inbox: allowed_inbox, user: target_agent)
      conversation = account.conversations.where(inbox: allowed_inbox, contact: contact).first

      patch "/api/v1/openjarvis/conversations/#{conversation.display_id}",
            params: { conversation: { team_id: target_team.id, assignee_id: target_agent.id } },
            headers: headers.merge('Idempotency-Key' => 'conversation-update-assignment-0001'),
            as: :json

      expect(response).to have_http_status(:ok)
      expect(conversation.reload).to have_attributes(team_id: target_team.id, assignee_id: target_agent.id)
    end

    it 'rejects an unsupported conversation status' do
      conversation = account.conversations.where(inbox: allowed_inbox, contact: contact).first

      patch "/api/v1/openjarvis/conversations/#{conversation.display_id}",
            params: { conversation: { status: 'waiting_for_magic' } },
            headers: headers.merge('Idempotency-Key' => 'conversation-update-invalid-status-0001'),
            as: :json

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body.dig('error', 'code')).to eq('invalid_status')
    end
  end

  describe 'scopes' do
    it 'rejects an operation not granted to the connection' do
      hook.update!(settings: hook.settings.merge('scopes' => ['inboxes:read']))

      get '/api/v1/openjarvis/contacts', headers: headers

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body.dig('error', 'code')).to eq('insufficient_scope')
    end
  end
end
