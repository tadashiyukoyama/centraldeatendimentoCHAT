FactoryBot.define do
  factory :channel_instagram, class: 'Channel::Instagram' do
    account
    access_token { SecureRandom.hex(32) }
    instagram_id { rand((10**15)...(10**16)).to_s }
    expires_at { 60.days.from_now }
    updated_at { 25.hours.ago }

    before :create do |channel|
      WebMock::API.stub_request(:post, "https://graph.instagram.com/v22.0/#{channel.instagram_id}/subscribed_apps")
                  .with(
                    headers: { 'Authorization' => "Bearer #{channel.access_token}" },
                    body: {
                      subscribed_fields: %w[comments live_comments message_reactions messages messaging_seen]
                    }.to_json
                  )
                  .to_return(
                    status: 200,
                    body: { success: true }.to_json,
                    headers: { 'Content-Type' => 'application/json' }
                  )

      WebMock::API.stub_request(:get, "https://graph.instagram.com/v22.0/#{channel.instagram_id}/subscribed_apps")
                  .with(headers: { 'Authorization' => "Bearer #{channel.access_token}" })
                  .to_return(
                    status: 200,
                    body: {
                      data: [
                        {
                          subscribed_fields: %w[messages message_reactions messaging_seen comments live_comments]
                        }
                      ]
                    }.to_json,
                    headers: { 'Content-Type' => 'application/json' }
                  )

      WebMock::API.stub_request(:delete, "https://graph.instagram.com/v22.0/#{channel.instagram_id}/subscribed_apps")
                  .with(query: {
                          access_token: channel.access_token
                        })
                  .to_return(status: 200, body: '', headers: {})
    end

    after(:create) do |channel|
      create(:inbox, channel: channel, account: channel.account)
    end
  end
end
