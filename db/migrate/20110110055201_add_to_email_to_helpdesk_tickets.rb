class AddToEmailToHelpdeskTickets < ActiveRecord::Migration
  def self.up
    add_column :helpdesk_tickets, :to_email, :string
  end

  def self.down
    remove_column :helpdesk_tickets, :to_email
  end
end
