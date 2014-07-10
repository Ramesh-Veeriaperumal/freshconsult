class AddPolymorphicToTimeSheets < ActiveRecord::Migration
  def self.up
	add_column :helpdesk_time_sheets, :workable_id, "bigint unsigned"
    add_column :helpdesk_time_sheets, :workable_type, :string , :default => 'Helpdesk::Ticket'

    add_index "helpdesk_time_sheets", ["account_id", "workable_type", "workable_id"], :name => "index_helpdesk_sheets_on_workable_account"
    add_index "helpdesk_time_sheets", ["workable_type", "workable_id"], :name => "index_helpdesk_sheets_on_workable"

    execute("update helpdesk_time_sheets set workable_id = ticket_id")

    remove_column :helpdesk_time_sheets, :ticket_id
  end

  def self.down
	remove_column :helpdesk_time_sheets, :workable_id
    remove_column :helpdesk_time_sheets, :workable_type
    add_column  :helpdesk_time_sheets, :ticket_id, "bigint unsigned"
  end
end
