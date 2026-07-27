require 'rails_helper'

RSpec.describe Instagram::CommentAutomation::ProcessEventJob do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:channel) { create(:channel_instagram, account: account, instagram_id: '17841400000000001') }
  let(:inbox) { channel.inbox }
  let(:automation) do
    create(
      :instagram_comment_automation,
      account: account,
      inbox: inbox,
      name: 'Demo',
      keywords: ['demo'],
      public_reply_template: 'Enviei no Direct, {{username}}.',
      private_reply_template: 'Você comentou {{keyword}}.',
      enabled: true
    )
  end
  let(:event) do
    create(
      :instagram_comment_event,
      account: account,
      inbox: inbox,
      instagram_comment_automation: automation,
      status: :matched,
      public_reply_status: :pending,
      private_reply_status: :pending,
      matched_keyword: 'demo'
    )
  end

  before do
    stub_request(:post, %r{/#{event.comment_id}/replies$})
      .to_return(status: 200, body: { id: 'public-reply-id' }.to_json)
    stub_request(:post, %r{/#{channel.instagram_id}/messages$})
      .to_return(
        status: 200,
        body: { recipient_id: event.sender_id, message_id: 'private-reply-id' }.to_json
      )
    WebMock::RequestRegistry.instance.reset!
  end

  it 'delivers each endpoint once and completes the ledger' do
    described_class.perform_now(event.id)

    event.reload
    expect(event).to be_completed
    expect(event).to be_public_reply_succeeded
    expect(event).to be_private_reply_succeeded
    expect(event.public_reply_external_id).to eq('public-reply-id')
    expect(event.private_reply_external_id).to eq('private-reply-id')
    expect(event.private_reply_recipient_id).to eq(event.sender_id)
  end

  it 'is idempotent after a terminal delivery' do
    described_class.perform_now(event.id)
    described_class.perform_now(event.id)

    expect(a_request(:post, %r{/#{event.comment_id}/replies$})).to have_been_made.once
    expect(a_request(:post, %r{/#{channel.instagram_id}/messages$})).to have_been_made.once
  end

  it 'preserves a successful endpoint while retrying only a transient failure' do
    stub_request(:post, %r{/#{channel.instagram_id}/messages$})
      .to_return(status: 429, body: { error: { code: 4, type: 'OAuthException' } }.to_json)

    expect { described_class.perform_now(event.id) }
      .to have_enqueued_job(described_class).with(event.id)

    event.reload
    expect(event).to be_retrying
    expect(event).to be_public_reply_succeeded
    expect(event).to be_private_reply_transient_failure
  end

  it 'records a permanent API rejection without retrying it' do
    stub_request(:post, %r{/#{channel.instagram_id}/messages$})
      .to_return(status: 400, body: { error: { code: 10, type: 'OAuthException' } }.to_json)

    expect { described_class.perform_now(event.id) }.not_to have_enqueued_job(described_class)

    event.reload
    expect(event).to be_partially_failed
    expect(event).to be_public_reply_succeeded
    expect(event).to be_private_reply_permanent_failure
    expect(event.private_reply_error_code).to eq('10')
  end

  it 'does not send when the automation was disabled after matching' do
    event
    automation.update!(enabled: false)

    described_class.perform_now(event.id)

    expect(event.reload).to be_ignored
    expect(event.ignore_reason).to eq('automation_unavailable')
    expect(a_request(:post, /graph\.instagram\.com/)).not_to have_been_made
  end
end
