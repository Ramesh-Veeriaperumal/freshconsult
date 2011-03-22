class AddGroupEscalatedToHelpdeskTicketStates < ActiveRecord::Migration
  def self.up
    add_column :helpdesk_ticket_states, :group_escalated, :boolean , :default => false
  end

  def self.down
    remove_column :helpdesk_ticket_states, :group_escalated
  end
end
