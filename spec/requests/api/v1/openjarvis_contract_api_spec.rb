require 'rails_helper'
require 'support/openjarvis_contract_schema_validator'

RSpec.describe 'OpenJarvis contract API', type: :request do
  let(:account) { create(:account) }
  let(:service_user) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:inbox, account: account) }
  let(:hook) do
    create(:integrations_hook, :openjarvis, account: account, service_user: service_user, allowed_inboxes: [inbox])
  end
  let(:headers) { { 'Authorization' => "Bearer #{hook.access_token}" } }
  let(:schema_validator) { OpenjarvisContractSchemaValidator.new }

  it 'serves the root and referenced OpenAPI 3.1 documents' do
    get '/api/v1/openjarvis/openapi', headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq('application/yaml')
    expect(response.body).to include('openapi: 3.1.0')

    get '/api/v1/openjarvis/openjarvis-openapi/schemas.yaml', headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('ErrorResponse:')

    get '/api/v1/openjarvis/openjarvis-openapi/not-allowed.yaml', headers: headers
    expect(response).to have_http_status(:not_found)
    expect(response.parsed_body.dig('error', 'code')).to eq('openapi_component_not_found')
  end

  it 'returns executable schemas, error taxonomy and formal channel capabilities' do
    get '/api/v1/openjarvis/catalog', headers: headers

    operation = response.parsed_body['operations'].find { |item| item['id'] == 'messages.create' }
    whatsapp = response.parsed_body.dig('channel_capabilities', 'Channel::Whatsapp')
    expect(operation).to include('executable' => true, 'idempotency_required' => true)
    expect(operation['input_schema']).to be_present
    expect(operation['output_schema']).to be_present
    expect(whatsapp.dig('messages.reaction', 'supported')).to be(false)
    expect(response.parsed_body.dig('errors', 'request_in_progress', 'result_state')).to eq('unknown')
  end

  it 'keeps system endpoint responses aligned with their published schemas' do
    {
      '/api/v1/openjarvis/catalog' => 'Catalog',
      '/api/v1/openjarvis/health' => 'Health',
      '/api/v1/openjarvis/diagnostics' => 'Diagnostics',
      '/api/v1/openjarvis/operations' => 'Operations'
    }.each do |path, schema_name|
      get path, headers: headers

      expect(response).to have_http_status(:ok)
      expect_schema(schema_name, response.parsed_body)
    end
  end

  it 'reports inbox connection separately from auto assignment' do
    inbox.update!(enable_auto_assignment: false)

    get "/api/v1/openjarvis/inboxes/#{inbox.id}/health", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('data', 'connection')).to include('state' => 'active', 'connected' => true)
    expect(response.parsed_body.dig('data', 'capabilities', 'messages.send', 'supported')).to be(true)

    get '/api/v1/openjarvis/inboxes', headers: headers
    expect(response.parsed_body.dig('data', 0, 'auto_assignment_enabled')).to be(false)
  end

  it 'accepts the previous Bearer token only during the rotation overlap' do
    old_token = hook.access_token
    hook.update!(
      previous_access_token: old_token,
      previous_access_token_expires_at: 1.hour.from_now,
      access_token: SecureRandom.urlsafe_base64(48)
    )

    get '/api/v1/openjarvis/health', headers: { 'Authorization' => "Bearer #{old_token}" }
    expect(response).to have_http_status(:ok)

    hook.update!(previous_access_token_expires_at: 1.minute.ago)
    get '/api/v1/openjarvis/health', headers: { 'Authorization' => "Bearer #{old_token}" }
    expect(response).to have_http_status(:unauthorized)
  end

  it 'paginates contacts deterministically and binds the cursor to filters' do
    timestamp = Time.zone.parse('2026-08-18 12:00:00')
    contacts = create_list(:contact, 3, account: account)
    contacts.each do |contact|
      create(:conversation, account: account, inbox: inbox, contact: contact)
      contact.update_columns(updated_at: timestamp) # rubocop:disable Rails/SkipsModelValidations
    end

    get '/api/v1/openjarvis/contacts', params: { limit: 2 }, headers: headers
    cursor = response.parsed_body.dig('meta', 'next_cursor')

    expect(response.parsed_body.dig('meta', 'has_more')).to be(true)
    expect(response.parsed_body['data'].pluck('id')).to eq(contacts.map(&:id).sort.last(2).reverse)

    get '/api/v1/openjarvis/contacts', params: { limit: 2, cursor: cursor, q: 'different-filter' }, headers: headers
    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body.dig('error', 'code')).to eq('invalid_cursor').or eq('cursor_mismatch')
  end

  it 'searches conversations by contact and inbox without crossing the allowlist' do
    contact = create(:contact, account: account)
    visible = create(:conversation, account: account, inbox: inbox, contact: contact)
    hidden_inbox = create(:inbox, account: account)
    create(:conversation, account: account, inbox: hidden_inbox, contact: contact)

    get '/api/v1/openjarvis/conversations', params: { contact_id: contact.id, inbox_id: inbox.id }, headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['data'].pluck('id')).to eq([visible.display_id])
    expect(response.parsed_body['meta']).to include('has_more' => false, 'next_cursor' => nil)
  end

  it 'searches unread messages and returns stable cursor metadata' do
    conversation = create(:conversation, account: account, inbox: inbox, agent_last_seen_at: 1.hour.ago)
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming, created_at: 2.hours.ago)
    unread = create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming, created_at: 5.minutes.ago)

    get '/api/v1/openjarvis/messages', params: { inbox_id: inbox.id, unread: true }, headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['data'].pluck('id')).to eq([unread.id])
    expect(response.parsed_body['meta']).to include('has_more' => false, 'next_cursor' => nil)
  end

  it 'serves individual contacts, conversations and conversation messages with published schemas' do
    contact = create(:contact, account: account)
    conversation = create(:conversation, account: account, inbox: inbox, contact: contact)
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming)

    {
      "/api/v1/openjarvis/contacts/#{contact.id}" => 'ContactResponse',
      "/api/v1/openjarvis/conversations/#{conversation.display_id}" => 'ConversationResponse',
      "/api/v1/openjarvis/conversations/#{conversation.display_id}/messages" => 'MessageListResponse'
    }.each do |path, schema_name|
      get path, headers: headers

      expect(response).to have_http_status(:ok)
      expect_schema(schema_name, response.parsed_body)
    end
  end

  it 'returns and replays a created conversation with its database-assigned public id' do
    contact = create(:contact, account: account)
    create(:conversation, account: account, inbox: inbox, contact: contact)
    request_headers = headers.merge('Idempotency-Key' => 'conversation-create-contract-0001')
    request_params = { conversation: { inbox_id: inbox.id, contact_id: contact.id } }

    post '/api/v1/openjarvis/conversations', params: request_params, headers: request_headers, as: :json

    expect(response).to have_http_status(:created)
    created_body = response.parsed_body
    created = account.conversations.find(created_body.dig('data', 'internal_id'))
    expect(created_body.dig('data', 'id')).to eq(created.display_id)
    expect(created_body.dig('data', 'id')).to be_present
    expect_schema('ConversationResponse', created_body)

    post '/api/v1/openjarvis/conversations', params: request_params, headers: request_headers, as: :json

    expect(response.headers['Idempotency-Replayed']).to eq('true')
    expect(response.parsed_body).to eq(created_body)
  end

  it 'updates a contact idempotently using the published response schema' do
    contact = create(:contact, account: account)
    create(:conversation, account: account, inbox: inbox, contact: contact)

    patch "/api/v1/openjarvis/contacts/#{contact.id}",
          params: { contact: { name: 'Updated Example' } },
          headers: headers.merge('Idempotency-Key' => 'contact-update-contract-0001'),
          as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('data', 'name')).to eq('Updated Example')
    expect_schema('ContactResponse', response.parsed_body)
  end

  it 'resolves agents, teams and labels before conversation mutations' do
    team = create(:team, account: account)
    label = create(:label, account: account)

    get '/api/v1/openjarvis/agents', params: { inbox_id: inbox.id }, headers: headers
    expect(response.parsed_body['data'].pluck('id')).to include(service_user.id)

    get '/api/v1/openjarvis/teams', headers: headers
    expect(response.parsed_body['data'].pluck('id')).to include(team.id)

    get '/api/v1/openjarvis/labels', headers: headers
    expect(response.parsed_body['data'].pluck('id')).to include(label.id)
  end

  it 'backfills snapshots with a stable ascending cursor' do
    contacts = create_list(:contact, 2, account: account)
    contacts.each { |contact| create(:conversation, account: account, inbox: inbox, contact: contact) }

    get '/api/v1/openjarvis/backfill', params: { resource: 'contacts', limit: 1 }, headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('data', 0)).to include('schema_version' => '1.0', 'event' => 'resource.snapshot')
    expect(response.parsed_body.dig('meta', 'has_more')).to be(true)
    expect(response.parsed_body.dig('meta', 'next_cursor')).to be_present
  end

  it 'marks read only in AceleraChat and is idempotent' do
    conversation = create(:conversation, account: account, inbox: inbox, agent_last_seen_at: nil)
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming)
    request_headers = headers.merge('Idempotency-Key' => 'mark-read-contract-0001')

    post "/api/v1/openjarvis/conversations/#{conversation.display_id}/read", headers: request_headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('data', 'provider_receipt_sent')).to be(false)
    expect(conversation.reload.agent_last_seen_at).to be_present

    post "/api/v1/openjarvis/conversations/#{conversation.display_id}/read", headers: request_headers
    expect(response.headers['Idempotency-Replayed']).to eq('true')
  end

  it 'returns a stable 429 envelope and Retry-After' do
    result = Openjarvis::RateLimiter::Result.new(allowed?: false, limit: 120, remaining: 0, retry_after: 17, reset_at: 17.seconds.from_now)
    allow(Openjarvis::RateLimiter).to receive(:new).and_return(instance_double(Openjarvis::RateLimiter, check: result))

    get '/api/v1/openjarvis/catalog', headers: headers

    expect(response).to have_http_status(:too_many_requests)
    expect(response.headers['Retry-After']).to eq('17')
    expect(response.parsed_body['error']).to include('code' => 'rate_limited', 'retryable' => true, 'result_state' => 'not_applied')
  end

  private

  def expect_schema(name, value)
    errors = schema_validator.errors(name, value)
    expect(errors).to be_empty, "Response does not match #{name}: #{errors.to_json}"
  end
end
