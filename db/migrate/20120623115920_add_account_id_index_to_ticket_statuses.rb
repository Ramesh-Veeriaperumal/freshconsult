class AddAccountIdIndexToTicketStatuses < ActiveRecord::Migration
  def self.up
  	add_index :helpdesk_ticket_statuses, :account_id, :name => 'index_helpdesk_ticket_statuses_on_account_id'
  end

  def self.down
  	remove_index :helpdesk_ticket_statuses, :account_id
  end
end
