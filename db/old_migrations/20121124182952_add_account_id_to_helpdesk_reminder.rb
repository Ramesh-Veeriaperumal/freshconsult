class AddAccountIdToHelpdeskReminder < ActiveRecord::Migration
  def self.up
  	add_column :helpdesk_reminders, :account_id, "bigint unsigned"
  end

  def self.down
  	remove_column :helpdesk_reminders, :account_id
  end
end
