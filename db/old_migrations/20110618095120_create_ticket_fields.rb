class CreateTicketFields < ActiveRecord::Migration
  def self.up
    create_table :helpdesk_ticket_fields do |t|
      t.integer :account_id,                :limit => 8
      t.string :name
      t.string :label
      t.string :label_in_portal
      t.text :description
      t.boolean :active,                    :default => true
      t.string :field_type
      t.integer :position
      t.boolean :required,                  :default => false
      t.boolean :visible_in_portal,         :default => false
      t.boolean :editable_in_portal,        :default => false
      t.boolean :required_in_portal,        :default => false
      t.boolean :required_for_closure,      :default => false
      t.integer :flexifield_def_entry_id,   :limit => 8

      t.timestamps
    end
    
    add_index :helpdesk_ticket_fields, [:account_id, :name], 
          :name => "index_helpdesk_ticket_fields_on_account_id_and_name", :unique => true
  end

  def self.down
    drop_table :helpdesk_ticket_fields
  end
end
