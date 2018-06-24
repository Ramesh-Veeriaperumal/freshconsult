class CreateCannedFormAndFormHandles < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    send(direction)
  end

  def up
    create_table :canned_forms do |t|
      t.integer :account_id, limit: 8, null: false
      t.string  :name
      t.string  :description
      t.text    :message
      t.boolean :deleted, default: false
      t.integer :version
      t.string  :service_form_id
      t.text    :serialized_form, limit: 16777215
      t.timestamps
    end

    add_index :canned_forms, :account_id

    create_table :canned_form_handles do |t|
      t.integer :ticket_id, limit: 8, null: false
      t.integer :account_id, limit: 8, null: false
      t.string  :id_token
      t.integer :canned_form_id, limit: 8, null: false
      t.integer :response_note_id, limit: 8
      t.text    :response_data
      t.timestamps
    end

    add_index :canned_form_handles, [:account_id, :id_token], length: { id_token: 20 }
  end

  def down
    drop_table :canned_forms
    drop_table :canned_form_handles
  end
end
