class AddScoreColumnsToAgents < ActiveRecord::Migration
  def self.up
    add_column :agents, :points, :integer, :limit => 8
    add_column :agents, :scoreboard_level_id, :integer, :limit => 8
  end

  def self.down
    remove_column :agents, :scoreboard_level_id
    remove_column :agents, :points
  end
end
