class AddOccasionalToAgents < ActiveRecord::Migration
  def self.up
    add_column :agents, :occasional, :boolean, :default => false
  end

  def self.down
    remove_column :agents, :occasional
  end
end
