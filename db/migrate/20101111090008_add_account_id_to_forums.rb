class AddAccountIdToForums < ActiveRecord::Migration
  def self.up
    add_column :forums, :account_id, :integer
    add_column :topics, :account_id, :integer
    add_column :posts, :account_id, :integer
  end

  def self.down
    remove_column :forums, :account_id
    remove_column :topics, :account_id
    remove_column :posts, :account_id
  end
end
