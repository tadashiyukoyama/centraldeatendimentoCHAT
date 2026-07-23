class CreateWhatsappEvolutionProvisionings < ActiveRecord::Migration[7.1]
  def change
    create_table :whatsapp_evolution_provisionings do |t|
      t.references :account, null: false, foreign_key: true
      t.references :whatsapp_channel,
                   foreign_key: { to_table: :channel_whatsapp },
                   index: { unique: true }
      t.string :public_id, null: false
      t.string :inbox_name, null: false
      t.string :instance_name, null: false
      t.text :instance_token, null: false
      t.text :webhook_secret, null: false
      t.integer :status, null: false, default: 0
      t.string :connected_number
      t.string :profile_name
      t.string :profile_picture_url
      t.string :last_error_code
      t.text :last_error_message
      t.datetime :last_seen_at
      t.datetime :expires_at, null: false
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    add_index :whatsapp_evolution_provisionings, :public_id, unique: true
    add_index :whatsapp_evolution_provisionings, :instance_name, unique: true
    create_table :whatsapp_evolution_events do |t|
      t.references :provisioning, null: false,
                                   foreign_key: { to_table: :whatsapp_evolution_provisionings },
                                   index: true
      t.string :event_key, null: false
      t.string :event_type, null: false
      t.integer :status, null: false, default: 0
      t.integer :attempts, null: false, default: 0
      t.string :last_error_class
      t.text :last_error_message
      t.datetime :processed_at

      t.timestamps
    end

    add_index :whatsapp_evolution_events, :event_key, unique: true
  end
end
