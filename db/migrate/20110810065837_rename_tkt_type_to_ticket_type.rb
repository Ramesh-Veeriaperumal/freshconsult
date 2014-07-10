class RenameTktTypeToTicketType < ActiveRecord::Migration
  def self.up
    rename_column :helpdesk_tickets, :tkt_type, :ticket_type
  end

  def self.down
    rename_column :helpdesk_tickets, :ticket_type, :tkt_type
  end
end
