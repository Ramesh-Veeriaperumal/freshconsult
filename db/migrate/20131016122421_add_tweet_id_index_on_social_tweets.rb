class AddTweetIdIndexOnSocialTweets < ActiveRecord::Migration
  shard :none
  def self.up
    Lhm.change_table :social_tweets, :atomic_switch => true do |m|
      m.ddl("ALTER TABLE %s ADD INDEX `index_social_tweets_on_tweet_id` (`account_id`,`tweet_id`) " % m.name)
    end
  end

  def self.down
    Lhm.change_table :social_tweets, :atomic_switch => true do |m|
      m.ddl("ALTER TABLE %s DROP INDEX `index_social_tweets_on_tweet_id` " % m.name)
    end
  end
end
