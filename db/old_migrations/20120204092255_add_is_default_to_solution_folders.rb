class AddIsDefaultToSolutionFolders < ActiveRecord::Migration
  def self.up
    add_column :solution_folders, :is_default, :boolean, :default => false
  end

  def self.down
    remove_column :solution_folders, :is_default
  end
end
