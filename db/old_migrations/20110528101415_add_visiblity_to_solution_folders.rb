class AddVisiblityToSolutionFolders < ActiveRecord::Migration
  def self.up
    add_column :solution_folders, :visibility, :integer , :limit => 8
  end

  def self.down
    remove_column :solution_folders, :visibility
  end
end
