class CreateCompanyForms < ActiveRecord::Migration

  shard :all

  def self.up
    create_table :company_forms do |t|
      t.column  :account_id,                'bigint unsigned'
      t.column  :parent_id,                 'bigint unsigned'
      t.boolean :active,                    :default => false
      t.text    :form_options
      t.timestamps
    end
    
    add_index :company_forms, [:account_id, :active, :parent_id],
          :name => "index_company_forms_on_account_id_and_active_and_parent_id"
  end

  def self.down
    drop_table :company_forms
  end
end