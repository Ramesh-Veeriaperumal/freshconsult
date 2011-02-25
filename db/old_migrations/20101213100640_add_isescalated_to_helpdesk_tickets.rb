class AddIsescalatedToHelpdeskTickets < ActiveRecord::Migration
  def self.up
    add_column :helpdesk_tickets, :isescalated, :boolean , :default => false
  end

  def self.down
    remove_column :helpdesk_tickets, :isescalated
  end
end
