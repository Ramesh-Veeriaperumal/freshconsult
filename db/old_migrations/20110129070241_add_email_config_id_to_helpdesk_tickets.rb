class AddEmailConfigIdToHelpdeskTickets < ActiveRecord::Migration
  def self.up
    add_column :helpdesk_tickets, :email_config_id, :integer
  end

  def self.down
    remove_column :helpdesk_tickets, :email_config_id
  end
end
