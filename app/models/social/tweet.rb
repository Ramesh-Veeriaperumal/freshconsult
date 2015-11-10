class Social::Tweet < ActiveRecord::Base

  include Social::Dynamo::Twitter

  self.table_name =  "social_tweets"
  self.primary_key = :id

  belongs_to :tweetable, :polymorphic => true
  belongs_to_account
  belongs_to :twitter_handle, :class_name => 'Social::TwitterHandle', :foreign_key => 'twitter_handle_id'

  attr_protected :tweetable_id

  validates_presence_of   :tweet_id, :account_id, :twitter_handle_id
  validates_uniqueness_of :tweet_id, :scope => :account_id, :message => "Tweet already converted as a ticket"
  
  after_destroy :remove_fd_link_in_dynamo

  TWEET_LENGTH = 140
  DM_LENGTH    = 10000
 

  TWEET_TYPES = [["Mention", :mention],["Direct Message",:dm]]

  def is_ticket?
    tweetable_type.eql?('Helpdesk::Ticket')
  end

  def is_note?
    tweetable_type.eql?('Helpdesk::Note')
  end

  def is_archive_ticket?
    tweetable_type.eql?('Helpdesk::ArchiveTicket')
  end

  def is_archive_note?
    tweetable_type.eql?('Helpdesk::ArchiveNote') 
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

  def get_archive_ticket
    return tweetable if is_archive_ticket?
    return tweetable.archive_ticket if is_archive_note?
  end
  
  def remove_fd_link_in_dynamo
    stream = Account.current.twitter_streams.find_by_id(self.stream_id) if self.stream_id
    return if stream.nil? or (stream && !stream.default_stream?)
    delete_fd_link("#{self.account_id}_#{self.stream_id}", self.tweet_id)
  end

end
