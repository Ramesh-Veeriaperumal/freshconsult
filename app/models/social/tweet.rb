class Social::Tweet < ActiveRecord::Base
  
  set_table_name "social_tweets"
  
  belongs_to :tweetable, :polymorphic => true
  belongs_to_account
  belongs_to :twitter_handle, :class_name => 'Social::TwitterHandle', :foreign_key => 'twitter_handle_id'
  
  attr_protected :tweetable_id
  
  validates_presence_of   :tweet_id, :account_id, :twitter_handle_id
  validates_uniqueness_of :tweet_id, :scope => :account_id, :message => "Tweet already converted as a ticket"
  
  LENGTH = 140
  
  TWEET_TYPES = [["Mention", :mention],["Direct Message",:dm]] 
  
  def is_ticket?
    tweetable_type.eql?('Helpdesk::Ticket')
  end
  
  def is_note?
    tweetable_type.eql?('Helpdesk::Note')
  end
  
  
  def get_ticket
    
    if is_ticket?
      return tweetable
    end
    
    if is_note?
     return tweetable.notable
    end
    
  end
  
end
