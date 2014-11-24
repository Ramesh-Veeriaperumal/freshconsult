class CreateContactForms < ActiveRecord::Migration

	shard :all

  def self.up
    create_table :contact_forms do |t|
      t.column  :account_id,                'bigint unsigned'
      t.column  :parent_id,                 'bigint unsigned'
      t.boolean :active,                    :default => false
      t.text    :form_options
      t.timestamps
    end
    
    add_index :contact_forms, [:account_id, :active, :parent_id],
          :name => "index_contact_forms_on_account_id_and_active_and_parent_id"
  end

  def self.down
    drop_table :contact_forms
  end

end
