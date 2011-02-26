class RemoveUnwantedFromTicket < ActiveRecord::Migration
  def self.up
    remove_column :helpdesk_tickets, :name
    remove_column :helpdesk_tickets, :phone
    remove_column :helpdesk_tickets, :email
    remove_column :helpdesk_tickets, :address
  end

  def self.down
    add_column :helpdesk_tickets, :address, :text
    add_column :helpdesk_tickets, :email, :string
    add_column :helpdesk_tickets, :phone, :string
    add_column :helpdesk_tickets, :name, :string
  end
end
