class AddAvailablityColumnToAgent < ActiveRecord::Migration
  def self.up
    add_column :agents, :available, :boolean, :default => true
  end

  def self.down
    remove_column :agents, :available
  end
end
