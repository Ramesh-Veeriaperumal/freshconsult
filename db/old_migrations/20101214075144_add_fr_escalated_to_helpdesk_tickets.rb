class AddFrEscalatedToHelpdeskTickets < ActiveRecord::Migration
  def self.up
    add_column :helpdesk_tickets, :fr_escalated, :boolean,  :default => false
  end

  def self.down
    remove_column :helpdesk_tickets, :fr_escalated
  end
end
