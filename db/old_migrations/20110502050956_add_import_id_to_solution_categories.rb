class AddImportIdToSolutionCategories < ActiveRecord::Migration
  def self.up
    add_column :solution_categories, :import_id, :integer
    add_column :solution_folders, :import_id, :integer
    add_column :solution_articles, :import_id, :integer
  end

  def self.down
    remove_column :solution_categories, :import_id
    remove_column :solution_folders, :import_id
    remove_column :solution_articles, :import_id
  end
end
