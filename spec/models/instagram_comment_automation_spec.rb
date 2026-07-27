require 'rails_helper'

RSpec.describe InstagramCommentAutomation do
  subject(:automation) do
    described_class.new(
      account: account,
      inbox: inbox,
      name: 'Demonstração',
      keywords: ['demo'],
      public_reply_enabled: true,
      public_reply_template: 'Enviei no Direct, {{username}}.',
      private_reply_enabled: true,
      private_reply_template: 'Você comentou {{keyword}}.',
      conversation_label: 'instagram_demo'
    )
  end

  let(:account) { create(:account) }
  let(:channel) { create(:channel_instagram, account: account) }
  let(:inbox) { channel.inbox }

  it 'accepts a valid account-scoped rule' do
    expect(automation).to be_valid
  end

  it 'normalizes keywords and removes duplicates' do
    automation.keywords = [' demo ', 'demo', '', nil]
    automation.validate

    expect(automation.keywords).to eq(['demo'])
  end

  it 'rejects an inbox from another account' do
    other_channel = create(:channel_instagram)
    automation.inbox = other_channel.inbox

    expect(automation).not_to be_valid
    expect(automation.errors[:inbox]).to include('must belong to the same account')
  end

  it 'rejects unsupported template variables' do
    automation.private_reply_template = 'Olá {{password}}'

    expect(automation).not_to be_valid
    expect(automation.errors[:base].join).to include('Unsupported template variables')
  end

  it 'requires at least one reply channel' do
    automation.public_reply_enabled = false
    automation.private_reply_enabled = false

    expect(automation).not_to be_valid
    expect(automation.errors[:base]).to include('at least one reply channel must be enabled')
  end

  it 'rejects a schedule ending before it starts' do
    automation.starts_at = 1.hour.from_now
    automation.ends_at = Time.current

    expect(automation).not_to be_valid
    expect(automation.errors[:ends_at]).to include('must be after the start time')
  end
end
