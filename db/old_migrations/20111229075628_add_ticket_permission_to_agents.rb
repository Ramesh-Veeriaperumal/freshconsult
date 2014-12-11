class AddTicketPermissionToAgents < ActiveRecord::Migration
  def self.up
    add_column :agents, :ticket_permission, :integer , :default => 1    
  end

  def self.down
    remove_column :agents, :ticket_permission
  end
end
