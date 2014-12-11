class AddCategoriesIdToPortals < ActiveRecord::Migration
  def self.up
    add_column :portals, :solution_category_id, :integer, :limit => 8
    add_column :portals, :forum_category_id, :integer, :limit => 8
  end

  def self.down
    remove_column :portals, :forum_category_id
    remove_column :portals, :solution_category_id
  end
end
