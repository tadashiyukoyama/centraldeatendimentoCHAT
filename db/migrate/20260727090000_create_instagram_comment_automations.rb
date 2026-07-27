class CreateInstagramCommentAutomations < ActiveRecord::Migration[7.1]
  def change
    create_automations_table
    create_events_table
  end

  private

  def create_automations_table
    create_table :instagram_comment_automations do |t|
      automation_ownership_columns(t)
      automation_match_columns(t)
      automation_reply_columns(t)
      automation_schedule_columns(t)
      t.timestamps
    end

    add_index :instagram_comment_automations, [:inbox_id, :enabled, :priority],
              name: 'idx_ig_comment_automations_inbox_enabled_priority'
    add_index :instagram_comment_automations, [:inbox_id, :name],
              unique: true, name: 'idx_ig_comment_automations_inbox_name'
    add_index :instagram_comment_automations, [:account_id, :created_at],
              name: 'idx_ig_comment_automations_account_created'
    add_check_constraint :instagram_comment_automations, 'priority BETWEEN -100 AND 100',
                         name: 'chk_ig_comment_automations_priority'
  end

  def automation_ownership_columns(table)
    table.references :account, null: false, foreign_key: { on_delete: :cascade }
    table.references :inbox, null: false, foreign_key: { on_delete: :cascade }
    table.references :created_by, foreign_key: { to_table: :users, on_delete: :nullify }
    table.references :updated_by, foreign_key: { to_table: :users, on_delete: :nullify }
    table.string :name, null: false
    table.boolean :enabled, null: false, default: false
  end

  def automation_match_columns(table)
    table.integer :match_type, null: false, default: 0
    table.jsonb :keywords, null: false, default: []
    table.string :media_id
    table.boolean :include_nested_replies, null: false, default: false
  end

  def automation_reply_columns(table)
    table.boolean :public_reply_enabled, null: false, default: true
    table.text :public_reply_template
    table.boolean :private_reply_enabled, null: false, default: true
    table.text :private_reply_template
    table.text :conversation_context
    table.string :conversation_label
  end

  def automation_schedule_columns(table)
    table.integer :priority, null: false, default: 0
    table.datetime :starts_at
    table.datetime :ends_at
    table.integer :lock_version, null: false, default: 0
  end

  # Events are the delivery ledger and idempotency boundary. We intentionally do
  # not store the complete webhook payload or access tokens.
  def create_events_table
    create_table :instagram_comment_events do |t|
      event_ownership_columns(t)
      event_source_columns(t)
      event_public_delivery_columns(t)
      event_private_delivery_columns(t)
      event_processing_columns(t)
      t.timestamps
    end

    add_index :instagram_comment_events, [:inbox_id, :comment_id],
              unique: true, name: 'idx_ig_comment_events_inbox_comment'
    add_index :instagram_comment_events, [:account_id, :status, :created_at],
              name: 'idx_ig_comment_events_account_status_created'
    add_index :instagram_comment_events, [:inbox_id, :private_reply_recipient_id, :created_at],
              name: 'idx_ig_comment_events_recipient_created'
    add_index :instagram_comment_events, [:status, :retry_at],
              name: 'idx_ig_comment_events_status_retry'
  end

  def event_ownership_columns(table)
    table.references :account, null: false, foreign_key: { on_delete: :cascade }
    table.references :inbox, null: false, foreign_key: { on_delete: :cascade }
    table.references :instagram_comment_automation,
                     foreign_key: { on_delete: :nullify },
                     index: { name: 'idx_ig_comment_events_automation' }
    table.references :conversation, foreign_key: { on_delete: :nullify }
  end

  def event_source_columns(table)
    table.string :comment_id, null: false
    table.string :sender_id
    table.string :sender_username
    table.string :media_id, null: false
    table.string :media_product_type
    table.string :parent_comment_id
    table.text :comment_text, null: false
    table.string :webhook_field, null: false
    table.integer :status, null: false, default: 0
    table.string :ignore_reason
    table.string :matched_keyword
  end

  def event_public_delivery_columns(table)
    table.integer :public_reply_status, null: false, default: 0
    table.string :public_reply_external_id
    table.string :public_reply_error_code
  end

  def event_private_delivery_columns(table)
    table.integer :private_reply_status, null: false, default: 0
    table.string :private_reply_recipient_id
    table.string :private_reply_external_id
    table.string :private_reply_error_code
  end

  def event_processing_columns(table)
    table.integer :processing_attempts, null: false, default: 0
    table.datetime :processing_started_at
    table.datetime :received_at, null: false
    table.datetime :processed_at
    table.datetime :retry_at
    table.integer :lock_version, null: false, default: 0
  end
end
