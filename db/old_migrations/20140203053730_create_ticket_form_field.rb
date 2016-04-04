class CreateTicketFormField < ActiveRecord::Migration
  shard :all
  def self.up
  	create_table :ticket_form_fields do |t|  
      t.integer     :account_id,  :limit => 8
      t.integer     :form_id,    :limit => 8
      t.integer     :ticket_field_id,    :limit => 8
      t.string      :ff_col_name
      t.string      :field_alias
      t.integer     :position,    :limit => 8
      t.boolean     :sub_section_field
      t.timestamps
    end

    add_index :ticket_form_fields, [:account_id,:form_id,:ticket_field_id],
    	:name => "index_form_tkt_fields_on_acc_id_and_form_id_and_field_id", 
    	:unique => true
    add_index :ticket_form_fields, [:account_id,:form_id]   
  end

  def self.down
  	drop_table :ticket_form_fields
  end
end