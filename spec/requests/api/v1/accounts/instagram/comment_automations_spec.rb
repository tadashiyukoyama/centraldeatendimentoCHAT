require 'rails_helper'

RSpec.describe 'Instagram comment automations API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:channel) { create(:channel_instagram, account: account) }
  let(:inbox) { channel.inbox }
  let(:path) { "/api/v1/accounts/#{account.id}/instagram/comment_automations" }
  let(:valid_attributes) do
    {
      name: 'Demo',
      enabled: false,
      match_type: 'whole_word',
      keywords: ['demo'],
      public_reply_enabled: true,
      public_reply_template: 'Enviei no Direct.',
      private_reply_enabled: true,
      private_reply_template: 'Olá {{username}}.',
      conversation_context: 'Lead de demonstração.',
      conversation_label: 'instagram_demo',
      priority: 10
    }
  end

  it 'requires authentication' do
    get path, params: { inbox_id: inbox.id }

    expect(response).to have_http_status(:unauthorized)
  end

  it 'allows administrators and rejects agents' do
    get path, params: { inbox_id: inbox.id }, headers: administrator.create_new_auth_token
    expect(response).to have_http_status(:ok)

    get path, params: { inbox_id: inbox.id }, headers: agent.create_new_auth_token
    expect(response).to have_http_status(:unauthorized)
  end

  it 'creates an account-scoped draft and records its administrator' do
    expect do
      post path,
           params: { inbox_id: inbox.id, comment_automation: valid_attributes },
           headers: administrator.create_new_auth_token,
           as: :json
    end.to change(InstagramCommentAutomation, :count).by(1)

    expect(response).to have_http_status(:created)
    automation = InstagramCommentAutomation.last
    expect(automation.account).to eq(account)
    expect(automation.inbox).to eq(inbox)
    expect(automation.created_by).to eq(administrator)
  end

  it 'cannot access an inbox from another account' do
    other_inbox = create(:channel_instagram).inbox

    get path,
        params: { inbox_id: other_inbox.id },
        headers: administrator.create_new_auth_token

    expect(response).to have_http_status(:not_found)
  end

  it 'blocks activation until Meta confirms comment subscriptions' do
    inbox
    result = Instagram::CommentAutomation::WebhookSubscriptionService::Result.new(
      success?: true,
      subscribed_fields: ['messages'],
      missing_fields: %w[comments live_comments],
      error_code: nil,
      error_type: nil
    )
    service = instance_double(Instagram::CommentAutomation::WebhookSubscriptionService, status: result)
    allow(Instagram::CommentAutomation::WebhookSubscriptionService).to receive(:new).and_return(service)

    post path,
         params: {
           inbox_id: inbox.id,
           comment_automation: valid_attributes.merge(enabled: true)
         },
         headers: administrator.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['code']).to eq('instagram_comment_subscription_required')
    expect(InstagramCommentAutomation.count).to eq(0)
  end
end
