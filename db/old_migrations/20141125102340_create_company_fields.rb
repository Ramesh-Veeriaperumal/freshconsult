class CreateCompanyFields < ActiveRecord::Migration

  shard :all

  def self.up
    create_table :company_fields do |t|
      t.column  :account_id,                'bigint unsigned'
      t.column  :company_form_id,           'bigint unsigned'
      t.string  :name
      t.string  :column_name
      t.string  :label
      t.integer :field_type
      t.integer :position
      t.boolean :deleted,                   :default => false
      t.boolean :required_for_agent,        :default => false
      t.text    :field_options
      t.timestamps
    end
    
    add_index :company_fields, [:account_id, :company_form_id, :name], 
          :length => {:account_id => nil, :company_form_id => nil, :name => 20},
          :name => "index_company_fields_on_account_id_and_company_form_id_and_name"
    add_index :company_fields, [:account_id, :company_form_id, :field_type], 
          :name => "idx_company_field_account_id_and_company_form_id_and_field_type"
    add_index :company_fields, [:account_id, :company_form_id, :position], 
          :name => "idx_company_field_account_id_and_company_form_id_and_position"
  end

  def self.down
    drop_table :company_fields
  end

end