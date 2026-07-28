# == Schema Information
#
# Table name: campaign_deliveries
#
#  id              :bigint           not null, primary key
#  error_message   :text
#  processed_at    :datetime
#  status          :integer          default("pending"), not null
#  campaign_id     :bigint           not null
#  contact_id      :bigint           not null
#  conversation_id :bigint
#
class CampaignDelivery < ApplicationRecord
  belongs_to :campaign
  belongs_to :contact
  belongs_to :conversation, optional: true

  enum status: {
    pending: 0,
    processing: 1,
    queued: 2,
    skipped: 3,
    failed: 4
  }

  validates :contact_id, uniqueness: { scope: :campaign_id }

  scope :unfinished, -> { where(status: [:pending, :processing]) }
end
