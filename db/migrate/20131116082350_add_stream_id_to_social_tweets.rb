class AddStreamIdToSocialTweets < ActiveRecord::Migration
  shard :all
  def self.up
    Lhm.change_table :social_tweets, :atomic_switch => true do |m|
      m.ddl("ALTER TABLE %s ADD COLUMN stream_id bigint unsigned " % m.name)
      m.ddl("ALTER TABLE %s ADD INDEX `index_social_tweets_on_stream_id` (`account_id`,`stream_id`) " % m.name)
    end
  end

  def self.down
    Lhm.change_table :social_tweets, :atomic_switch => true do |m|
      m.ddl("ALTER TABLE %s DROP COLUMN stream_id " % m.name)
    end
  end
end
