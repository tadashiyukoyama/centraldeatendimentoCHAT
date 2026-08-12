class AddScheduledForToCampaignDeliveries < ActiveRecord::Migration[7.0]
  def change
    add_column :campaign_deliveries, :scheduled_for, :datetime
    add_index :campaign_deliveries, [:campaign_id, :scheduled_for]
  end
end
