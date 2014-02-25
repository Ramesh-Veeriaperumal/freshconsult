class CreateTicketFieldValues < ActiveRecord::Migration
  shard :all
  def self.up
  	create_table :ticket_field_values do |t|  
      t.integer     :account_id,  :limit => 8
      t.integer     :form_id,    :limit => 8
      t.integer     :ticket_field_id,    :limit => 8
      t.string      :value
      t.integer     :position,    :limit => 8
      t.timestamps
    end
    
    add_index :ticket_field_values, [:account_id,:form_id,:ticket_field_id]   
  end

  def self.down
  	drop_table :ticket_field_values
  end
end
