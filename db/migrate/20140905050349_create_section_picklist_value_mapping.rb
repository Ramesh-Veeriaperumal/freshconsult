class CreateSectionPicklistValueMapping < ActiveRecord::Migration
  shard :all
  def self.up
  	create_table :section_picklist_value_mappings do |t|  
      t.integer     :account_id,  				:limit => 8
      t.integer     :section_id,    			:limit => 8
      t.integer     :picklist_value_id,   :limit => 8
      t.timestamps
    end 
  end
  
  add_index :section_picklist_value_mappings, [:account_id, :section_id], 
            :name => 'index_sec_picklist_mappings_on_account_id_and_section_id'
  def self.down
  	drop_table :section_picklist_value_mappings
  end
end
