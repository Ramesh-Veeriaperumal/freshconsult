class RemovePriorityIdFromHelpdeskTickets < ActiveRecord::Migration
  def self.up
    remove_column :helpdesk_tickets, :priority_id
    add_column :helpdesk_tickets, :priority, :integer
  end

  def self.down
    remove_column :helpdesk_tickets, :priority
    add_column :helpdesk_tickets, :priority_id, :integer
  end
end
