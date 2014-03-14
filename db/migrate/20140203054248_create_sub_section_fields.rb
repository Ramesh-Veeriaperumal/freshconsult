class CreateSubSectionFields < ActiveRecord::Migration
  shard :all
  def self.up
  	create_table :sub_section_fields do |t|  
      t.integer     :account_id,  :limit => 8
      t.integer     :ticket_field_value_id,    :limit => 8
      t.integer     :ticket_field_id,    :limit => 8
      t.integer     :position,    :limit => 8
      t.timestamps
    end

    add_index :sub_section_fields, [:account_id,:ticket_field_value_id]   
  end

  def self.down
  	drop_table :sub_section_fields
  end
end
