class AddFrDueByToHelpdeskTickets < ActiveRecord::Migration
  def self.up
    add_column :helpdesk_tickets, :frDueBy, :datetime
  end

  def self.down
    remove_column :helpdesk_tickets, :frDueBy
  end
end
