class CreateCampaignDeliveries < ActiveRecord::Migration[7.0]
  def change
    create_table :campaign_deliveries do |t|
      t.references :campaign, null: false, foreign_key: { on_delete: :cascade }
      t.references :contact, null: false, foreign_key: { on_delete: :cascade }
      t.references :conversation, null: true, foreign_key: { on_delete: :nullify }
      t.integer :status, null: false, default: 0
      t.text :error_message
      t.datetime :processed_at

      t.timestamps
    end

    add_index :campaign_deliveries, [:campaign_id, :contact_id], unique: true
    add_index :campaign_deliveries, [:campaign_id, :status]
  end
end
