class CreateCompanyFieldChoices < ActiveRecord::Migration

	shard :all

  def self.up
    create_table :company_field_choices do |t|
      t.column  :account_id,                'bigint unsigned'
      t.column  :company_field_id,          'bigint unsigned'
      t.string 	:value
      t.integer :position
      t.timestamps
    end
    
    add_index :company_field_choices, [:account_id, :company_field_id, :position], #will acc_id, position and company_field_id be better? #check :include => :picklist_values query
          :name => "idx_cf_choices_on_account_id_and_company_field_id_and_position"
  end

  def self.down
    drop_table :company_field_picklist_values
  end

end