class CreateHelpdeskTimeSheets < ActiveRecord::Migration
  def self.up
    create_table :helpdesk_time_sheets do |t|
      t.integer :ticket_id, :limit => 8
      t.datetime :start_time
      t.integer :time_spent, :limit => 8
      t.boolean :timer_running , :default => false
      t.boolean :billable, :default =>true
      t.integer :user_id, :limit => 8
      t.text    :note
      t.integer :account_id,:limit => 8

      t.timestamps
    end
    
    add_index :helpdesk_time_sheets, [:ticket_id], :name => "index_time_sheets_on_ticket_id"
    add_index :helpdesk_time_sheets, [:user_id], :name => "index_time_sheets_on_user_id"
    add_index :helpdesk_time_sheets, [:account_id, :ticket_id], :name => "index_time_sheets_on_account_id_and_ticket_id" 
    
          
  end

  def self.down
    drop_table :helpdesk_time_sheets
  end
end
