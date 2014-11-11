class CreateContactFields < ActiveRecord::Migration

	shard :all

  def self.up
    create_table :contact_fields do |t|
      t.column  :account_id,                'bigint unsigned'
      t.string 	:name
      t.string 	:label
      t.string 	:label_in_portal
      t.boolean :deleted,                   :default => false
      t.string 	:field_type
      t.integer :position
      t.boolean :required_for_agent,        :default => false
      t.boolean :visible_in_portal,         :default => false
      t.boolean :editable_in_portal,        :default => false
      t.boolean :editable_in_signup,        :default => false
      t.boolean :required_in_portal,        :default => false
      t.column  :flexifield_def_entry_id,   'bigint unsigned'
      t.text    :field_options
      t.timestamps
    end
    
    add_index :contact_fields, [:account_id, :name], 
          :name => "index_contact_fields_on_account_id_and_name"
    add_index :contact_fields, [:account_id, :deleted], 
          :name => "index_contact_fields_on_account_id_and_deleted"
  end

  def self.down
    drop_table :contact_fields
  end

end
