class AddForumTypeToForum < ActiveRecord::Migration
  def self.up
    add_column :forums, :forum_type, :integer
  end

  def self.down
    remove_column :forums, :forum_type
  end
end
