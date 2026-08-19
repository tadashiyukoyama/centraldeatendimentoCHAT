require 'rails_helper'

RSpec.describe 'OpenJarvis Evolution WhatsApp actions', type: :request do
  let(:account) { create(:account) }
  let(:service_user) { create(:user, account: account, role: :administrator) }
  let(:channel) do
    create(
      :channel_whatsapp,
      account: account,
      provider: 'evolution',
      validate_provider_config: false,
      sync_templates: false
    )
  end
  let(:inbox) { channel.inbox }
  let(:contact_inbox) { create(:contact_inbox, inbox: inbox, source_id: '5511999999999') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact_inbox: contact_inbox) }
  let(:provider_service) { instance_double(Whatsapp::Providers::EvolutionService) }
  let(:hook) do
    create(
      :integrations_hook,
      :openjarvis,
      account: account,
      service_user: service_user,
      allowed_inboxes: [inbox]
    )
  end
  let(:headers) { { 'Authorization' => "Bearer #{hook.access_token}" } }

  before do
    create(:whatsapp_evolution_provisioning, account: account, whatsapp_channel: channel, status: :connected)
    allow(Whatsapp::Providers::EvolutionService).to receive(:new).and_return(provider_service)
  end

  it 'reacts once and replays the idempotent response without a second provider mutation' do
    message = create(:message, :incoming, account: account, conversation: conversation, source_id: 'provider-message-id')
    allow(provider_service).to receive(:send_reaction).and_return({})
    request_headers = headers.merge('Idempotency-Key' => 'reaction-request-0001')

    2.times do
      post "/api/v1/openjarvis/conversations/#{conversation.display_id}/messages/#{message.id}/reaction",
           params: { reaction: '👍' }, headers: request_headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('data', 'result_state')).to eq('applied')
    end

    expect(response.headers['Idempotency-Replayed']).to eq('true')
    expect(provider_service).to have_received(:send_reaction).once
  end

  it 'sends provider read receipts once and persists the internal read marker' do
    create(:message, :incoming, account: account, conversation: conversation, source_id: 'provider-message-id')
    allow(provider_service).to receive(:mark_messages_read).and_return({})
    request_headers = headers.merge('Idempotency-Key' => 'provider-read-request-0001')

    post "/api/v1/openjarvis/conversations/#{conversation.display_id}/provider_read", headers: request_headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('data', 'provider_receipt_sent')).to be(true)
    expect(conversation.reload.agent_last_seen_at).to be_present
    expect(provider_service).to have_received(:mark_messages_read).once
  end

  it 'creates a contextual reply without calling Evolution inside the request' do
    target = create(:message, :incoming, account: account, conversation: conversation, source_id: 'provider-target-id')
    allow(provider_service).to receive(:send_message)

    post "/api/v1/openjarvis/conversations/#{conversation.display_id}/messages",
         params: { message: { content: 'Resposta aprovada', reply_to_message_id: target.id } },
         headers: headers.merge('Idempotency-Key' => 'reply-request-0001'),
         as: :json

    expect(response).to have_http_status(:created)
    created = conversation.messages.outgoing.last
    expect(created.content_attributes).to include(
      'in_reply_to' => target.id,
      'in_reply_to_external_id' => 'provider-target-id'
    )
    expect(provider_service).not_to have_received(:send_message)
  end

  it 'attaches SSRF-fetched media without fetching or sending real content in the request spec' do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new('sanitized-test-media'),
      filename: 'catalogo.pdf',
      content_type: 'application/pdf'
    )
    fetcher = instance_double(Openjarvis::RemoteAttachmentFetcher, fetch!: blob)
    allow(Openjarvis::RemoteAttachmentFetcher).to receive(:new)
      .with('https://media.example.test/catalogo.pdf')
      .and_return(fetcher)
    allow(provider_service).to receive(:send_message)

    post "/api/v1/openjarvis/conversations/#{conversation.display_id}/messages",
         params: {
           message: {
             content: 'Catálogo',
             remote_attachment: { url: 'https://media.example.test/catalogo.pdf' }
           }
         },
         headers: headers.merge('Idempotency-Key' => 'media-request-0001'),
         as: :json

    expect(response).to have_http_status(:created)
    created = conversation.messages.outgoing.last
    expect(created.attachments.one?).to be(true)
    expect(created.attachments.first.file.blob).to eq(blob)
    expect(provider_service).not_to have_received(:send_message)
  end

  it 'enforces the inbox allowlist and dedicated reaction scope before calling Evolution' do
    hidden_inbox = create(:inbox, account: account)
    hidden_conversation = create(:conversation, account: account, inbox: hidden_inbox)
    hidden_message = create(:message, :incoming, account: account, conversation: hidden_conversation, source_id: 'hidden')
    allow(provider_service).to receive(:send_reaction)

    post "/api/v1/openjarvis/conversations/#{hidden_conversation.display_id}/messages/#{hidden_message.id}/reaction",
         params: { reaction: '👍' }, headers: headers.merge('Idempotency-Key' => 'reaction-hidden-0001'), as: :json
    expect(response).to have_http_status(:not_found)

    hook.update!(settings: hook.settings.merge('scopes' => ['messages:read']))
    message = create(:message, :incoming, account: account, conversation: conversation, source_id: 'visible')
    post "/api/v1/openjarvis/conversations/#{conversation.display_id}/messages/#{message.id}/reaction",
         params: { reaction: '👍' }, headers: headers.merge('Idempotency-Key' => 'reaction-scope-0001'), as: :json
    expect(response).to have_http_status(:forbidden)
    expect(provider_service).not_to have_received(:send_reaction)
  end
end
