class Social::Tweet < ActiveRecord::Base

  self.table_name =  "social_tweets"
  self.primary_key = :id

  belongs_to :tweetable, :polymorphic => true
  belongs_to_account
  belongs_to :twitter_handle, :class_name => 'Social::TwitterHandle', :foreign_key => 'twitter_handle_id'

  attr_protected :tweetable_id

  validates_presence_of   :tweet_id, :account_id, :twitter_handle_id
  validates_uniqueness_of :tweet_id, :scope => :account_id, :message => "Tweet already converted as a ticket"

  TWEET_LENGTH = 140
  DM_LENGTH    = 10000
 

  TWEET_TYPES = [["Mention", :mention],["Direct Message",:dm]]

  def is_ticket?
    tweetable_type.eql?('Helpdesk::Ticket')
  end

  def is_note?
    tweetable_type.eql?('Helpdesk::Note')
  end

   def is_mention?
    tweet_type.eql?('mention')
  end

  def is_dm?
    tweet_type.eql?('dm')
  end

  def get_ticket
    return tweetable if is_ticket?
    return tweetable.notable if is_note?
  end

end
