class CreateCaptainOperationalRecords < ActiveRecord::Migration[7.1]
  # The migration intentionally keeps the three related tables in one atomic,
  # declarative change so a partial operational-tool schema cannot be deployed.
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def change
    create_table :captain_tool_executions do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :assistant,
                   null: false,
                   foreign_key: { to_table: :captain_assistants, on_delete: :cascade }
      t.references :conversation, foreign_key: { on_delete: :nullify }
      t.references :contact, foreign_key: { on_delete: :nullify }
      t.string :tool_name, null: false
      t.integer :status, null: false, default: 0
      t.jsonb :request_summary, null: false, default: {}
      t.jsonb :result_summary, null: false, default: {}
      t.string :error_code
      t.string :idempotency_key
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.timestamps

      t.index [:account_id, :tool_name, :created_at], name: 'idx_captain_tool_executions_account_tool_created'
      t.index [:account_id, :tool_name, :idempotency_key],
              unique: true,
              where: 'idempotency_key IS NOT NULL',
              name: 'idx_captain_tool_executions_idempotency'
    end

    create_table :captain_appointments do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :assistant,
                   null: false,
                   foreign_key: { to_table: :captain_assistants, on_delete: :cascade }
      t.references :conversation, null: false, foreign_key: { on_delete: :cascade }
      t.references :contact, null: false, foreign_key: { on_delete: :cascade }
      t.references :specialist, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :kind, null: false, default: 'demo'
      t.integer :status, null: false, default: 0
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :timezone, null: false
      t.text :notes
      t.string :idempotency_key, null: false
      t.string :external_provider
      t.string :external_id
      t.jsonb :metadata, null: false, default: {}
      t.timestamps

      t.index [:account_id, :idempotency_key], unique: true
      t.index [:account_id, :specialist_id, :starts_at], name: 'idx_captain_appointments_specialist_start'
      t.index [:account_id, :status, :starts_at], name: 'idx_captain_appointments_status_start'
      t.index [:external_provider, :external_id],
              unique: true,
              where: 'external_provider IS NOT NULL AND external_id IS NOT NULL',
              name: 'idx_captain_appointments_external'
    end

    create_table :captain_payment_notices do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :assistant,
                   null: false,
                   foreign_key: { to_table: :captain_assistants, on_delete: :cascade }
      t.references :conversation, null: false, foreign_key: { on_delete: :cascade }
      t.references :contact, null: false, foreign_key: { on_delete: :cascade }
      t.references :verified_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.integer :status, null: false, default: 0
      t.bigint :amount_cents
      t.string :currency, null: false, default: 'BRL'
      t.datetime :reported_paid_at
      t.string :reference
      t.text :notes
      t.datetime :verified_at
      t.string :idempotency_key, null: false
      t.string :external_provider
      t.string :external_id
      t.jsonb :metadata, null: false, default: {}
      t.timestamps

      t.index [:account_id, :idempotency_key], unique: true
      t.index [:account_id, :contact_id, :created_at], name: 'idx_captain_payment_notices_contact_created'
      t.index [:account_id, :status, :created_at], name: 'idx_captain_payment_notices_status_created'
      t.index [:external_provider, :external_id],
              unique: true,
              where: 'external_provider IS NOT NULL AND external_id IS NOT NULL',
              name: 'idx_captain_payment_notices_external'
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
end
