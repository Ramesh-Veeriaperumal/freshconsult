class AddResponseTimeToHelpdeskTickets < ActiveRecord::Migration
  def self.up
    add_column :helpdesk_tickets, :response_time, :datetime
  end

  def self.down
    remove_column :helpdesk_tickets, :response_time
  end
end
