require 'rails_helper'

RSpec.describe Instagram::CommentAutomation::ApiClient do
  let(:channel) { create(:channel_instagram, instagram_id: '17841400000000001', access_token: 'instagram-token') }
  let(:client) { described_class.new(channel) }

  it 'sends a public reply with the token only in the authorization header' do
    request = stub_request(:post, 'https://graph.instagram.com/v22.0/18000000000000001/replies')
              .with(
                headers: {
                  'Authorization' => 'Bearer instagram-token',
                  'Content-Type' => 'application/json'
                },
                body: { message: 'Obrigado!' }.to_json
              )
              .to_return(status: 200, body: { id: '18000000000000002' }.to_json)

    result = client.reply_publicly(comment_id: '18000000000000001', text: 'Obrigado!')

    expect(result.success?).to be true
    expect(result.body['id']).to eq('18000000000000002')
    expect(request).to have_been_requested.once
  end

  it 'sends the single private reply using the comment id' do
    request = stub_request(:post, 'https://graph.instagram.com/v22.0/17841400000000001/messages')
              .with(
                headers: { 'Authorization' => 'Bearer instagram-token' },
                body: {
                  recipient: { comment_id: '18000000000000001' },
                  message: { text: 'Mensagem privada' }
                }.to_json
              )
              .to_return(
                status: 200,
                body: { recipient_id: '17840000000000999', message_id: 'mid-1' }.to_json
              )

    result = client.reply_privately(comment_id: '18000000000000001', text: 'Mensagem privada')

    expect(result.success?).to be true
    expect(result.body['recipient_id']).to eq('17840000000000999')
    expect(request).to have_been_requested.once
  end

  it 'classifies Graph rate-limit codes as transient without exposing the token' do
    stub_request(:post, /graph\.instagram\.com/)
      .to_return(status: 400, body: { error: { code: 4, type: 'OAuthException' } }.to_json)

    result = client.reply_publicly(comment_id: '18000000000000001', text: 'Obrigado!')

    expect(result.success?).to be false
    expect(result.transient?).to be true
    expect(result.error_code).to eq('4')
    expect(result.body.to_s).not_to include('instagram-token')
  end

  it 'rejects non-numeric object identifiers before making a request' do
    expect { client.reply_publicly(comment_id: '../token', text: 'x') }
      .to raise_error(ArgumentError, /Invalid Instagram object identifier/)
  end
end
