class RemoveForumCategoryIdFromProduct < ActiveRecord::Migration
  def self.up
    remove_column :products, :forum_category_id
  end

  def self.down
    add_column :products, :forum_category_id, :integer
  end
end
