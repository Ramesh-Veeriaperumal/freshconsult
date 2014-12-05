class CreateContactFieldChoices < ActiveRecord::Migration

	shard :all

  def self.up
    create_table :contact_field_choices do |t|
      t.column  :account_id,                'bigint unsigned'
      t.column  :contact_field_id,          'bigint unsigned'
      t.string 	:value
      t.integer :position
      t.timestamps
    end
    
    add_index :contact_field_choices, [:account_id, :contact_field_id, :position], #will acc_id, position and contact_field_id be better? #check :include => :picklist_values query
          :name => "idx_cf_choices_on_account_id_and_contact_field_id_and_position"
  end

  def self.down
    drop_table :contact_field_choices
  end

end
