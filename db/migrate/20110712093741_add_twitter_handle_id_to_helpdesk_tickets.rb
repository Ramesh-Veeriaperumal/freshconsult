class AddTwitterHandleIdToHelpdeskTickets < ActiveRecord::Migration
  def self.up
    add_column :helpdesk_tickets, :twitter_handle_id, :integer, :limit => 8
  end

  def self.down
    remove_column :helpdesk_tickets, :twitter_handle_id
  end
end
