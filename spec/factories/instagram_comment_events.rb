FactoryBot.define do
  factory :instagram_comment_event do
    account
    association :inbox, factory: :inbox
    instagram_comment_automation { nil }
    sequence(:comment_id) { |number| (18_000_000_000_000_000 + number).to_s }
    sender_id { '17_000_000_000_000_001' }
    sender_username { 'cliente_teste' }
    media_id { '18_000_000_000_000_101' }
    comment_text { 'Quero uma demo' }
    webhook_field { 'comments' }
    received_at { Time.current }

    after(:build) do |event|
      next if event.inbox&.instagram?

      channel = build(:channel_instagram, account: event.account)
      event.inbox = build(:inbox, account: event.account, channel: channel)
    end
  end
end
