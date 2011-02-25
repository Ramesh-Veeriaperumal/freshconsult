class AddCategoryIdToSolutionFolders < ActiveRecord::Migration
  def self.up
    add_column :solution_folders, :category_id, :integer
    remove_column :solution_folders, :account_id
  end

  def self.down
    remove_column :solution_folders, :category_id
    add_column :solution_folders, :account_id, :integer
  end
end
