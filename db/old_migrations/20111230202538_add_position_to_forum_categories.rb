class AddPositionToForumCategories < ActiveRecord::Migration
  def self.up
    add_column :forum_categories, :position, :integer
  end

  def self.down
    remove_column :forum_categories, :position
  end
end
