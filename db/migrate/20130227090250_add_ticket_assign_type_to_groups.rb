class AddTicketAssignTypeToGroups < ActiveRecord::Migration
  def self.up
    add_column :groups, :ticket_assign_type, :integer, :default => 0
  end

  def self.down
    remove_column :groups, :ticket_assign_type
  end
end
