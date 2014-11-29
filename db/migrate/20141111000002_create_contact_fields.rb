class CreateContactFields < ActiveRecord::Migration

  shard :all

  def self.up
    create_table :contact_fields do |t|
      t.column  :account_id,                'bigint unsigned'
      t.column  :contact_form_id,           'bigint unsigned'
      t.string  :name
      t.string  :column_name
      t.string  :label
      t.string  :label_in_portal
      t.integer :field_type
      t.integer :position
      t.boolean :deleted,                   :default => false
      t.boolean :required_for_agent,        :default => false
      t.boolean :visible_in_portal,         :default => false
      t.boolean :editable_in_portal,        :default => false
      t.boolean :editable_in_signup,        :default => false
      t.boolean :required_in_portal,        :default => false
      t.text    :field_options
      t.timestamps
    end
    
    add_index :contact_fields, [:account_id, :contact_form_id, :name], 
          :length => {:account_id => nil, :contact_form_id => nil, :name => 20},
          :name => "index_contact_fields_on_account_id_and_contact_form_id_and_name"
    add_index :contact_fields, [:account_id, :contact_form_id, :field_type], 
          :name => "idx_contact_field_account_id_and_contact_form_id_and_field_type"
    add_index :contact_fields, [:account_id, :contact_form_id, :position], 
          :name => "idx_contact_field_account_id_and_contact_form_id_and_position"
  end

  def self.down
    drop_table :contact_fields
  end

end
