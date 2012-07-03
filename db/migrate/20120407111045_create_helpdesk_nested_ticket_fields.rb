class CreateHelpdeskNestedTicketFields < ActiveRecord::Migration
  def self.up
    create_table :helpdesk_nested_ticket_fields do |t|
      t.column :account_id, "bigint unsigned"
      t.column :ticket_field_id, "bigint unsigned"
      t.string :name
      t.string :label
      t.string :label_in_portal
      t.string :description
      t.column :flexifield_def_entry_id, "bigint unsigned"
      t.integer :level

      t.timestamps
    end

    add_index :helpdesk_nested_ticket_fields, [:account_id, :name], 
          :name => "index_helpdesk_nested_ticket_fields_on_account_id_and_name", :unique => true
  end

  def self.down
    drop_table :helpdesk_nested_ticket_fields
  end
end
