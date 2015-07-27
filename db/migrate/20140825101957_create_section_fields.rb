class CreateSectionFields < ActiveRecord::Migration
  shard :all
  def self.up
  	create_table :helpdesk_section_fields do |t|  
      t.integer     :account_id,      :limit => 8
      t.integer     :section_id,      :limit => 8
      t.integer     :ticket_field_id, :limit => 8
      t.integer     :parent_ticket_field_id,  :limit => 8
      t.integer     :position,        :limit => 8
      t.text        :options
      t.timestamps

    add_index :helpdesk_section_fields, [:account_id,:section_id], 
              :name => 'index_helpdesk_section_fields_on_account_id_and_section_id'  
    end
  end

  def self.down
  	drop_table :helpdesk_section_fields
  end
end
