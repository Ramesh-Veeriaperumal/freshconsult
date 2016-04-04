class AddIndexAccountIdOnPosts < ActiveRecord::Migration
  def self.up
	add_index :posts, [:account_id, :created_at], :name => 'index_posts_on_account_id_and_created_at'
  end

  def self.down
	remove_index :posts, [:account_id, :created_at]
  end
end
