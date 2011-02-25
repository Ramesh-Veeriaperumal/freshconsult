class RemoveAccessTokenFromHelpdeskTickets < ActiveRecord::Migration
  def self.up
    remove_column :helpdesk_tickets, :access_token
  end

  def self.down
    add_column :helpdesk_tickets, :access_token, :string
  end
end
