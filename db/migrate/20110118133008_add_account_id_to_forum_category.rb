class AddAccountIdToForumCategory < ActiveRecord::Migration
  def self.up
    add_column :forum_categories, :account_id, :integer
  end

  def self.down
    remove_column :forum_categories, :account_id
  end
end
