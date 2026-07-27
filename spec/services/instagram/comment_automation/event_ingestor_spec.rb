require 'rails_helper'

RSpec.describe Instagram::CommentAutomation::EventIngestor do
  include ActiveJob::TestHelper

  subject(:ingestor) do
    described_class.new(
      channel: channel,
      webhook_field: 'comments',
      payload: payload,
      entry_time: Time.current.to_i
    )
  end

  let(:account) { create(:account) }
  let(:channel) { create(:channel_instagram, account: account, instagram_id: '17841400000000001') }
  let(:inbox) { channel.inbox }
  let!(:automation) do
    create(
      :instagram_comment_automation,
      account: account,
      inbox: inbox,
      keywords: ['demo'],
      public_reply_enabled: true,
      private_reply_enabled: true
    )
  end
  let(:payload) do
    {
      id: '18000000000000001',
      from: { id: '17840000000000999', username: 'cliente' },
      text: 'Quero uma DEMO!',
      media: { id: '18000000000000111', media_product_type: 'FEED' }
    }
  end

  it 'persists one normalized event and enqueues delivery' do
    expect { ingestor.call }
      .to change(InstagramCommentEvent, :count).by(1)
      .and have_enqueued_job(Instagram::CommentAutomation::ProcessEventJob)

    event = InstagramCommentEvent.last
    expect(event).to be_matched
    expect(event.instagram_comment_automation).to eq(automation)
    expect(event.matched_keyword).to eq('demo')
    expect(event).to be_public_reply_pending
    expect(event).to be_private_reply_pending
  end

  it 'deduplicates webhook retries by inbox and comment id' do
    ingestor.call

    expect { ingestor.call }.not_to change(InstagramCommentEvent, :count)
    expect(enqueued_jobs.count { |job| job[:job] == Instagram::CommentAutomation::ProcessEventJob }).to eq(1)
  end

  it 'records unmatched comments without scheduling a send' do
    payload[:text] = 'Apenas uma dúvida'

    expect { ingestor.call }.not_to have_enqueued_job(Instagram::CommentAutomation::ProcessEventJob)

    event = InstagramCommentEvent.last
    expect(event).to be_ignored
    expect(event.ignore_reason).to eq('no_matching_rule')
  end

  it 'ignores comments from the connected professional account' do
    payload[:from][:id] = channel.instagram_id

    expect { ingestor.call }.not_to have_enqueued_job(Instagram::CommentAutomation::ProcessEventJob)

    expect(InstagramCommentEvent.last.ignore_reason).to eq('self_comment')
  end

  it 'does not persist malformed events' do
    payload[:media].delete(:id)

    expect { ingestor.call }.not_to change(InstagramCommentEvent, :count)
  end
end
