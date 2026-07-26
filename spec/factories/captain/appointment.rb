FactoryBot.define do
  factory :captain_appointment, class: 'Captain::Appointment' do
    association :conversation
    account { conversation.account }
    assistant { association(:captain_assistant, account: account) }
    contact { conversation.contact }
    specialist { association(:user, account: account) }
    starts_at { 2.days.from_now }
    ends_at { starts_at + 30.minutes }
    timezone { 'America/Sao_Paulo' }
    sequence(:idempotency_key) { |number| "appointment-#{number}" }
  end
end
