require 'rails_helper'

RSpec.describe Webhooks::InstagramCommentEventsJob do
  let(:account) { create(:account) }
  let(:channel) { create(:channel_instagram, account: account, instagram_id: '17841400000000001') }

  let(:entries) do
    [
      {
        id: channel.instagram_id,
        time: Time.current.to_i,
        changes: [
          {
            field: 'comments',
            value: {
              id: '18000000000000001',
              from: { id: '17840000000000999', username: 'cliente' },
              text: 'demo',
              media: { id: '18000000000000111', media_product_type: 'REELS' }
            }
          }
        ]
      }
    ]
  end

  it 'routes each supported normalized change to the ingestor' do
    ingestor = instance_double(Instagram::CommentAutomation::EventIngestor, call: true)
    allow(Instagram::CommentAutomation::EventIngestor).to receive(:new).and_return(ingestor)

    described_class.perform_now(entries)

    expect(Instagram::CommentAutomation::EventIngestor).to have_received(:new).with(
      channel: channel,
      webhook_field: 'comments',
      payload: hash_including(id: '18000000000000001'),
      entry_time: kind_of(Integer)
    )
    expect(ingestor).to have_received(:call)
  end

  it 'accepts the direct field and value shape used by Instagram Login webhooks' do
    direct_entry = entries.first.except(:changes).merge(
      field: 'comments',
      value: entries.first.dig(:changes, 0, :value)
    )
    ingestor = instance_double(Instagram::CommentAutomation::EventIngestor, call: true)
    allow(Instagram::CommentAutomation::EventIngestor).to receive(:new).and_return(ingestor)

    described_class.perform_now([direct_entry])

    expect(Instagram::CommentAutomation::EventIngestor).to have_received(:new).with(
      channel: channel,
      webhook_field: 'comments',
      payload: hash_including(id: '18000000000000001'),
      entry_time: kind_of(Integer)
    )
  end

  it 'ignores unsupported webhook fields' do
    entries.first[:changes].first[:field] = 'mentions'
    allow(Instagram::CommentAutomation::EventIngestor).to receive(:new)

    described_class.perform_now(entries)

    expect(Instagram::CommentAutomation::EventIngestor).not_to have_received(:new)
  end
end
