FactoryBot.define do
  factory :captain_payment_notice, class: 'Captain::PaymentNotice' do
    association :conversation
    account { conversation.account }
    assistant { association(:captain_assistant, account: account) }
    contact { conversation.contact }
    sequence(:idempotency_key) { |number| "payment-notice-#{number}" }
  end
end
