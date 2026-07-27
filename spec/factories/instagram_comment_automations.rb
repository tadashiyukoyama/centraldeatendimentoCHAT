FactoryBot.define do
  factory :instagram_comment_automation do
    account
    association :inbox, factory: :inbox
    sequence(:name) { |number| "Instagram demo #{number}" }
    enabled { true }
    match_type { :whole_word }
    keywords { ['demo'] }
    public_reply_enabled { true }
    public_reply_template { 'Enviei uma mensagem no Direct, {{username}}.' }
    private_reply_enabled { true }
    private_reply_template { 'Olá, {{username}}. Você comentou {{keyword}}.' }
    conversation_context { 'Lead interessado em uma demonstração.' }
    conversation_label { 'instagram_demo' }

    after(:build) do |automation|
      next if automation.inbox&.instagram?

      channel = build(:channel_instagram, account: automation.account)
      automation.inbox = build(:inbox, account: automation.account, channel: channel)
    end
  end
end
