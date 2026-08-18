class CreateOpenjarvisWebhookDeliveries < ActiveRecord::Migration[7.1]
  def change
    create_table :openjarvis_webhook_deliveries do |t|
      t.references :integration_hook, null: false, foreign_key: { to_table: :integrations_hooks }
      t.string :delivery_id, null: false
      t.string :event_name, null: false
      t.string :resource_type
      t.bigint :resource_id
      t.string :payload_digest, null: false
      t.integer :status, null: false, default: 0
      t.integer :attempts, null: false, default: 0
      t.integer :response_status
      t.string :error_code
      t.string :error_message
      t.datetime :delivered_at
      t.timestamps

      t.index :delivery_id, unique: true
      t.index [:integration_hook_id, :created_at], name: 'idx_openjarvis_deliveries_hook_created'
      t.index [:integration_hook_id, :status], name: 'idx_openjarvis_deliveries_hook_status'
    end
  end
end
