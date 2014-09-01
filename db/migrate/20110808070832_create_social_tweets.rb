class CreateSocialTweets < ActiveRecord::Migration
  def self.up
    create_table :social_tweets do |t|
      t.integer :tweet_id , :limit => 8
      t.integer :tweetable_id , :limit => 8
      t.string  :tweetable_type
      t.timestamps
    end
  end

  def self.down
    drop_table  :social_tweets
  end
end
