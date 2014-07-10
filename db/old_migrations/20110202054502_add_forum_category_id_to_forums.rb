class AddForumCategoryIdToForums < ActiveRecord::Migration
  def self.up
    add_column :forums, :forum_category_id, :integer
  end

  def self.down
    remove_column :forums, :forum_category_id
  end
end
