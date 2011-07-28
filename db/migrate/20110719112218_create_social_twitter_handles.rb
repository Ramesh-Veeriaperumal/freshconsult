class CreateSocialTwitterHandles < ActiveRecord::Migration
  def self.up
    create_table :social_twitter_handles do |t|
     
      t.integer :twitter_user_id ,:limit => 8
      t.string  :screen_name 
      t.string  :access_token
      t.string  :access_secret
      t.boolean :capture_dm_as_ticket ,:default => true
      t.boolean :capture_mention_as_ticket , :default => true
      t.integer :product_id ,:limit => 8
      t.integer :last_dm_id ,:limit => 8
      t.integer :last_mention_id ,:limit => 8
      t.integer :account_id
      t.text    :search_keys
      t.timestamps
      
    end
    
    add_index :social_twitter_handles, [:account_id,:twitter_user_id], 
          :name => "index_account_product_id", :unique => true
    
    add_index :social_twitter_handles, :product_id, 
          :name => "index_product_id", :unique => true
    
  end

  def self.down
    drop_table :social_twitter_handles
  end
end
