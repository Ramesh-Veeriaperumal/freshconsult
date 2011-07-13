class CreateAdminTwitterHandles < ActiveRecord::Migration
  def self.up
    create_table :admin_twitter_handles do |t|
      t.integer :twitter_user_id ,:limit => 8
      t.integer :user_id ,:limit => 8
      t.string  :access_token
      t.string  :access_secret
      t.boolean :capture_dm_as_ticket ,:default => true
      t.boolean :capture_mention_as_ticket , :default => true
      t.boolean :primary , :default => false
      t.integer :group_id , :limit => 8
      t.integer :product_id ,:limit => 8
      t.integer :account_id ,:limit => 8
      t.integer :last_dm_id ,:limit => 8
      t.integer :last_mention_id ,:limit => 8      

      t.timestamps
    end
  end

  def self.down
    drop_table :admin_twitter_handles
  end
end
