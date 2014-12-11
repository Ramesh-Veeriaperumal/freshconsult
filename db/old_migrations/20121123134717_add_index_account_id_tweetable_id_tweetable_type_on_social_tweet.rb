class AddIndexAccountIdTweetableIdTweetableTypeOnSocialTweet < ActiveRecord::Migration
  def self.up
  	execute <<-SQL
  		CREATE INDEX `index_social_tweets_account_id_tweetable_id_tweetable_type` ON social_tweets (`account_id`,`tweetable_id`,`tweetable_type`(15))
  	SQL
  end

  def self.down
  	execute <<-SQL
  		DROP INDEX `index_social_tweets_account_id_tweetable_id_tweetable_type` ON social_tweets
  	SQL
  end
end
