class AddAccountIdToSocialTweets < ActiveRecord::Migration
  def self.up
    add_column :social_tweets, :account_id, :integer
  end

  def self.down
    remove_column :social_tweets, :account_id
  end
end
