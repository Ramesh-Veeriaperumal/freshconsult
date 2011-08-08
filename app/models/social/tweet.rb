class Social::Tweet < ActiveRecord::Base
  
  set_table_name "social_tweets"
  
  belongs_to :tweetable, :polymorphic => true
  
  attr_protected :tweetable_id
  
  validates_presence_of :tweet_id
  
end
