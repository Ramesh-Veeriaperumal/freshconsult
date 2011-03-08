class AddCcEmailToHelpdeskTicket < ActiveRecord::Migration
  def self.up
    add_column :helpdesk_tickets, :cc_email, :text
  end

  def self.down
    remove_column :helpdesk_tickets, :cc_email
  end
end
