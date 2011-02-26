class RemoveVirtualAgents < ActiveRecord::Migration
  def self.up
    drop_table :virtual_agents
  end

  def self.down
  end
end
