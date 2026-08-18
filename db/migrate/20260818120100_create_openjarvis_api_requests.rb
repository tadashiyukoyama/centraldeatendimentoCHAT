class CreateOpenjarvisApiRequests < ActiveRecord::Migration[7.1]
  def change
    create_table :openjarvis_api_requests do |t|
      t.references :integration_hook, null: false, foreign_key: { to_table: :integrations_hooks }
      t.string :idempotency_key, null: false
      t.string :operation, null: false
      t.string :request_digest, null: false
      t.integer :status, null: false, default: 0
      t.integer :response_status
      t.text :response_body
      t.string :resource_type
      t.bigint :resource_id
      t.datetime :completed_at
      t.timestamps

      t.index [:integration_hook_id, :idempotency_key], unique: true, name: 'idx_openjarvis_requests_hook_key'
      t.index [:integration_hook_id, :created_at], name: 'idx_openjarvis_requests_hook_created'
      t.index [:resource_type, :resource_id], name: 'idx_openjarvis_requests_resource'
    end
  end
end
