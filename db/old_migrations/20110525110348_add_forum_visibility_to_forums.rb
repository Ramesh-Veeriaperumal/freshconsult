class AddForumVisibilityToForums < ActiveRecord::Migration
  def self.up
    add_column :forums, :forum_visibility, :integer
  end

  def self.down
    remove_column :forums, :forum_visibility
  end
end
