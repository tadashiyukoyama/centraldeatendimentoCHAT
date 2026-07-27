require 'rails_helper'

RSpec.describe Instagram::CommentAutomation::KeywordMatcher do
  let(:account) { create(:account) }
  let(:channel) { create(:channel_instagram, account: account) }
  let(:inbox) { channel.inbox }

  def create_rule(**attributes)
    create(
      :instagram_comment_automation,
      {
        account: account,
        inbox: inbox,
        public_reply_enabled: true,
        public_reply_template: 'Resposta',
        private_reply_enabled: false
      }.merge(attributes)
    )
  end

  it 'matches whole words case- and accent-insensitively' do
    rule = create_rule(keywords: ['demonstração'])

    match = described_class.new(
      inbox: inbox,
      text: 'QUERO uma demonstracao, por favor!',
      media_id: '123',
      nested_reply: false
    ).call

    expect(match.automation).to eq(rule)
    expect(match.keyword).to eq('demonstração')
  end

  it 'does not match a keyword inside another word in whole-word mode' do
    create_rule(keywords: ['demo'])

    match = described_class.new(
      inbox: inbox,
      text: 'Quero demonstrar',
      media_id: '123',
      nested_reply: false
    ).call

    expect(match).to be_nil
  end

  it 'honors publication scope and deterministic priority' do
    lower = create_rule(name: 'General', keywords: ['demo'], priority: 1)
    higher = create_rule(name: 'Post 123', keywords: ['demo'], priority: 10, media_id: '123')

    match = described_class.new(
      inbox: inbox,
      text: 'demo',
      media_id: '123',
      nested_reply: false
    ).call

    expect(match.automation).to eq(higher)
    expect(match.automation).not_to eq(lower)
  end

  it 'ignores nested replies unless explicitly enabled' do
    create_rule(keywords: ['demo'], include_nested_replies: false)

    match = described_class.new(
      inbox: inbox,
      text: 'demo',
      media_id: '123',
      nested_reply: true
    ).call

    expect(match).to be_nil
  end
end
