class AddTwitterHandleIdToSocialTweets < ActiveRecord::Migration
   def self.up
    add_column :social_tweets, :twitter_handle_id, "bigint unsigned"
  end

  def self.down
    remove_column :social_tweets, :twitter_handle_id
  end
end
