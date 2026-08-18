class HardenOpenjarvisContract < ActiveRecord::Migration[7.1]
  def change
    add_credential_rotation_columns
    add_retention_columns
    add_webhook_delivery_columns
    backfill_contract_metadata
    create_resource_sequences
  end

  private

  def add_credential_rotation_columns
    change_table :integrations_hooks, bulk: true do |t|
      t.string :previous_access_token
      t.datetime :previous_access_token_expires_at
      t.string :previous_webhook_secret
      t.datetime :previous_webhook_secret_expires_at
    end

    add_index :integrations_hooks, :previous_access_token,
              where: "app_id = 'openjarvis' AND previous_access_token IS NOT NULL",
              name: 'idx_openjarvis_hooks_previous_token'
  end

  def add_retention_columns
    change_table :openjarvis_api_requests, bulk: true do |t|
      t.datetime :expires_at
    end
    add_index :openjarvis_api_requests, :expires_at
  end

  def add_webhook_delivery_columns
    change_table :openjarvis_webhook_deliveries, bulk: true do |t|
      t.uuid :event_id
      t.string :schema_version, null: false, default: '1.0'
      t.string :resource_version
      t.bigint :resource_sequence
      t.string :failure_class
      t.datetime :next_attempt_at
      t.datetime :expires_at
    end
    add_index :openjarvis_webhook_deliveries, :event_id, unique: true
    add_index :openjarvis_webhook_deliveries, :expires_at
    add_index :openjarvis_webhook_deliveries,
              [:integration_hook_id, :resource_type, :resource_id, :resource_sequence],
              name: 'idx_openjarvis_deliveries_resource_sequence'
  end

  def backfill_contract_metadata
    reversible do |direction|
      direction.up do
        execute <<~SQL.squish
          UPDATE openjarvis_api_requests
          SET expires_at = created_at + INTERVAL '30 days'
          WHERE expires_at IS NULL
        SQL
        execute <<~SQL.squish
          UPDATE openjarvis_webhook_deliveries
          SET event_id = COALESCE(event_id, gen_random_uuid()),
              expires_at = COALESCE(expires_at, created_at + INTERVAL '30 days')
          WHERE event_id IS NULL OR expires_at IS NULL
        SQL
      end
    end
    change_column_null :openjarvis_webhook_deliveries, :event_id, false
  end

  def create_resource_sequences
    create_table :openjarvis_resource_sequences do |t|
      t.references :integration_hook, null: false, foreign_key: { to_table: :integrations_hooks }
      t.string :resource_type, null: false
      t.bigint :resource_id, null: false
      t.bigint :sequence, null: false, default: 0
      t.timestamps

      t.index [:integration_hook_id, :resource_type, :resource_id],
              unique: true,
              name: 'idx_openjarvis_resource_sequences_unique'
    end
  end
end
