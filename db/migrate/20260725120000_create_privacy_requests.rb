class CreatePrivacyRequests < ActiveRecord::Migration[7.1]
  # Declarative schema definition is intentionally kept in one reversible migration.
  def change # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    create_table :privacy_requests do |t|
      t.string :protocol, null: false
      t.integer :request_type, null: false
      t.integer :status, null: false, default: 0
      t.string :locale, null: false, default: 'pt_BR'
      t.text :email
      t.text :details
      t.text :resolution_notes
      t.string :verification_token_digest, null: false
      t.string :status_token_digest, null: false
      t.datetime :verification_expires_at, null: false
      t.datetime :verified_at
      t.datetime :due_at
      t.datetime :completed_at
      t.datetime :purged_at
      t.datetime :metadata_expires_at
      t.references :account, foreign_key: true, null: true
      t.jsonb :subprocessor_actions, null: false, default: []
      t.timestamps
    end

    add_index :privacy_requests, :protocol, unique: true
    add_index :privacy_requests, :verification_token_digest, unique: true
    add_index :privacy_requests, :status_token_digest, unique: true
    add_index :privacy_requests, %i[status due_at]
    add_index :privacy_requests, %i[status created_at]
    add_index :privacy_requests, %i[status completed_at]
    add_index :privacy_requests, :metadata_expires_at

    create_table :privacy_request_events do |t|
      t.references :privacy_request, null: false, foreign_key: true, index: true
      t.string :event_type, null: false
      t.string :from_status
      t.string :to_status
      t.string :actor_type
      t.bigint :actor_id
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :privacy_request_events, %i[actor_type actor_id]
  end
end
