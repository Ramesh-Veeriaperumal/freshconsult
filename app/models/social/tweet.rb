class Social::Tweet < ActiveRecord::Base
  
  set_table_name "social_tweets"
  
  belongs_to :tweetable, :polymorphic => true
  belongs_to :account
  
  attr_protected :tweetable_id
  
  validates_presence_of :tweet_id,:account_id
  validates_uniqueness_of :tweet_id, :scope => :account_id
  
end
