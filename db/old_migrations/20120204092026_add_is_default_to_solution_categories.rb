class AddIsDefaultToSolutionCategories < ActiveRecord::Migration
  def self.up
    add_column :solution_categories, :is_default, :boolean, :default => false
  end

  def self.down
    remove_column :solution_categories, :is_default
  end
end
