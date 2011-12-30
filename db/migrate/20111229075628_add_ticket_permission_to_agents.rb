class AddTicketPermissionToAgents < ActiveRecord::Migration
  def self.up
    add_column :agents, :ticket_permission, :integer
    
     Agent.all.each do |agent|
      agent.update_attribute(:ticket_permission , 1) #1 - all tickets..
    end
    
  end

  def self.down
    remove_column :agents, :ticket_permission
  end
end
