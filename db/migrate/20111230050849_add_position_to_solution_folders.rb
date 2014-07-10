class AddPositionToSolutionFolders < ActiveRecord::Migration
  def self.up
    add_column :solution_folders, :position, :integer
  end

  def self.down
    remove_column :solution_folders, :position
  end
end
