class RemoveTicketTypeFromHelpdeskTickets < ActiveRecord::Migration
  def self.up
    remove_column :helpdesk_tickets, :ticket_type
  end

  def self.down
    add_column :helpdesk_tickets, :ticket_type, :integer
  end
end
