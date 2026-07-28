# frozen_string_literal: true

FactoryBot.define do
  factory :campaign_delivery do
    campaign
    contact { association :contact, account: campaign.account }
  end
end
