class AddAccountIdToHelpdeskTicketStates < ActiveRecord::Migration
  def self.up
    add_column :helpdesk_ticket_states, :account_id, "bigint unsigned",:null => false
  end

  def self.down
    remove_column :helpdesk_ticket_states, :account_id
  end
end
