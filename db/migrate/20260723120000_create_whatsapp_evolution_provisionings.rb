class CreateWhatsappEvolutionProvisionings < ActiveRecord::Migration[7.1]
  def change
    create_provisionings_table
    add_index :whatsapp_evolution_provisionings, :public_id, unique: true
    add_index :whatsapp_evolution_provisionings, :instance_name, unique: true
    create_events_table
    add_index :whatsapp_evolution_events, :event_key, unique: true
  end

  private

  def create_provisionings_table
    create_table :whatsapp_evolution_provisionings do |t|
      add_provisioning_identity(t)
      add_provisioning_connection_state(t)
      add_provisioning_lifecycle(t)
      t.timestamps
    end
  end

  def add_provisioning_identity(table)
    table.references :account, null: false, foreign_key: true
    table.references :whatsapp_channel,
                     foreign_key: { to_table: :channel_whatsapp },
                     index: { unique: true }
    table.string :public_id, null: false
    table.string :inbox_name, null: false
    table.string :instance_name, null: false
    table.text :instance_token, null: false
    table.text :webhook_secret, null: false
  end

  def add_provisioning_connection_state(table)
    table.integer :status, null: false, default: 0
    table.string :connected_number
    table.string :profile_name
    table.string :profile_picture_url
  end

  def add_provisioning_lifecycle(table)
    table.string :last_error_code
    table.text :last_error_message
    table.datetime :last_seen_at
    table.datetime :expires_at, null: false
    table.integer :lock_version, null: false, default: 0
  end

  def create_events_table
    create_table :whatsapp_evolution_events do |t|
      t.references(
        :provisioning,
        null: false,
        foreign_key: { to_table: :whatsapp_evolution_provisionings },
        index: true
      )
      t.string :event_key, null: false
      t.string :event_type, null: false
      t.integer :status, null: false, default: 0
      t.integer :attempts, null: false, default: 0
      t.string :last_error_class
      t.text :last_error_message
      t.datetime :processed_at

      t.timestamps
    end
  end
end
