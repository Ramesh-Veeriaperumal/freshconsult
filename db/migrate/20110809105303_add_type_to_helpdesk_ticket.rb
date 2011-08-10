class AddTypeToHelpdeskTicket < ActiveRecord::Migration
  def self.up
    add_column :helpdesk_tickets, :tkt_type, :string
  end

  def self.down
    remove_column :helpdesk_tickets, :tkt_type
  end
end
