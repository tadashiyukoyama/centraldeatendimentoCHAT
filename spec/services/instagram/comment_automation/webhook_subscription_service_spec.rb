require 'rails_helper'

RSpec.describe Instagram::CommentAutomation::WebhookSubscriptionService do
  subject(:service) { described_class.new(channel) }

  let(:channel) { build(:channel_instagram) }
  let(:client) { instance_double(Instagram::CommentAutomation::ApiClient) }

  before do
    allow(Instagram::CommentAutomation::ApiClient).to receive(:new).with(channel).and_return(client)
  end

  it 'reports exactly which required webhook fields are missing' do
    allow(client).to receive(:subscribed_fields).and_return(
      api_result(body: { 'subscribed_fields' => %w[messages message_reactions messaging_seen] })
    )

    result = service.status

    expect(result.success?).to be true
    expect(result.missing_fields).to contain_exactly('comments', 'live_comments')
  end

  it 'subscribes the complete field set and verifies it with a read-after-write' do
    existing_fields = %w[messages message_reactions messaging_seen mentions]
    allow(client).to receive(:subscribe)
      .with(fields: (existing_fields + %w[comments live_comments]).sort)
      .and_return(api_result(body: { 'success' => true }))
    allow(client).to receive(:subscribed_fields).and_return(
      api_result(body: { 'subscribed_fields' => existing_fields }),
      api_result(body: { 'subscribed_fields' => existing_fields + %w[comments live_comments] })
    )

    result = service.subscribe

    expect(result.success?).to be true
    expect(result.missing_fields).to be_empty
    expect(client).to have_received(:subscribe).once
    expect(client).to have_received(:subscribed_fields).twice
  end

  private

  def api_result(body:)
    Instagram::CommentAutomation::ApiClient::Result.new(
      success?: true,
      transient?: false,
      status: 200,
      body: body,
      error_code: nil,
      error_type: nil
    )
  end
end
