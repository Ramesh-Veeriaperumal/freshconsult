class AddTicketTypeToHelpdeskTickets < ActiveRecord::Migration
  def self.up
    remove_column :helpdesk_tickets, :ticket_type_id
    add_column :helpdesk_tickets, :ticket_type, :integer
  end

  def self.down
    remove_column :helpdesk_tickets, :ticket_type
    add_column :helpdesk_tickets, :ticket_type_id, :integer
  end
end
