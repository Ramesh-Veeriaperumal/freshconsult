class RemovePriorityFromHelpdeskTickets < ActiveRecord::Migration
  def self.up
    remove_column :helpdesk_tickets, :priority
    add_column :helpdesk_tickets, :priority, :integer, :default => 1
  end

  def self.down
    remove_column :helpdesk_tickets, :priority, :integer, :default => 1
    add_column :helpdesk_tickets, :priority, :integer
    
  end
end
