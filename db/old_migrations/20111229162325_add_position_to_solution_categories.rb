class AddPositionToSolutionCategories < ActiveRecord::Migration
  def self.up
    add_column :solution_categories, :position, :integer
  end

  def self.down
    remove_column :solution_categories, :position
  end
end
