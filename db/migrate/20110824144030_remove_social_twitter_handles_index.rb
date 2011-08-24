class RemoveSocialTwitterHandlesIndex < ActiveRecord::Migration
  def self.up
    remove_index :social_twitter_handles, :name => "index_product_id"
    remove_index :social_twitter_handles, :name => "index_account_product_id"
    
    add_index :social_twitter_handles, [:account_id, :twitter_user_id], 
                     :name => "social_twitter_handle_product_id", :unique => true
  end

  def self.down
    add_index :social_twitter_handles, [:account_id,:twitter_user_id], 
          :name => "index_account_product_id", :unique => true
    
    add_index :social_twitter_handles, :product_id, 
          :name => "index_product_id", :unique => true
          
    remove_index :social_twitter_handles, :name => "social_twitter_handle_product_id"

  end
end