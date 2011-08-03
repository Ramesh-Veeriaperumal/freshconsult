class AddInBoundCountToHelpdeskTicketStates < ActiveRecord::Migration
  def self.up
    add_column :helpdesk_ticket_states, :inbound_count, :integer, :default => 1
  end

  def self.down
    remove_column :helpdesk_ticket_states, :inbound_count
  end
end
