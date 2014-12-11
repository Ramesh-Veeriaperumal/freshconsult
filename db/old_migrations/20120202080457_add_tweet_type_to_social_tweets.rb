class AddTweetTypeToSocialTweets < ActiveRecord::Migration
  def self.up
    add_column :social_tweets, :tweet_type, :string , :default => 'mention'
  end

  def self.down
    remove_column :social_tweets, :tweet_type
  end
end
