class AddTicketAssignTypeToGroups < ActiveRecord::Migration
  def self.up
    add_column :groups, :ticket_assign_type, :integer, :default => 0
    add_column :groups, :max_open_tickets, :integer, :default => 5
  end

  def self.down
    remove_column :groups, :max_open_tickets
    remove_column :groups, :ticket_assign_type
  end
end
