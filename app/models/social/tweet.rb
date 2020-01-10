class Social::Tweet < ActiveRecord::Base

  include Social::Twitter::Util
  self.table_name =  "social_tweets"
  self.primary_key = :id

  belongs_to :tweetable, :polymorphic => true
  belongs_to_account
  belongs_to :twitter_handle, :class_name => 'Social::TwitterHandle', :foreign_key => 'twitter_handle_id'
  belongs_to :stream
  attr_protected :tweetable_id

  validates_presence_of :tweet_id, :account_id, :twitter_handle_id
  validates_uniqueness_of :tweet_id, :scope => :account_id, :message => Social::Constants::TWEET_ALREADY_EXISTS
  
  before_update :persist_previous_changes
  after_commit :publish_note_for_tweet, unless: :not_allowed_to_publish?
  after_destroy :remove_fd_link_in_dynamo

  TWEET_LENGTH = 280
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
    dynamo_twt_feed = Social::Dynamo::Twitter.new
    stream = Account.current.twitter_streams.find_by_id(self.stream_id) if self.stream_id
    return if stream.nil? or (stream && !stream.default_stream?)
    dynamo_twt_feed.delete_fd_link("#{self.account_id}_#{self.stream_id}", self.tweet_id)
  end

  def persist_previous_changes
    @previous_changes = changes
  end

  def destroy_action?
    transaction_include_action?(:destroy)
  end

  def not_allowed_to_publish?
    # For incoming mention and DM, source additional info is published via ticket/note create
    is_ticket? || is_archive_ticket? || tweetable.incoming || tweetable.import_id.present? || destroy_action?
  end

  def mention_stream_tweet?
    stream = tweetable.tweet.stream
    is_note? && stream.present? && stream.default_stream?
  end

  def publish_note_for_tweet
    # For outgoing DM and Mentions, source additional info is published via note create with tweet_id as nil
    return if tweet_id < 0 && (is_dm? || mention_stream_tweet?)

    old_payload = transaction_include_action?(:create) ? {} : construct_tweet_payload_for_central(self, tweetable, @previous_changes)
    new_payload = construct_tweet_payload_for_central(self, tweetable)
    tweetable.model_changes = { source_additional_info: { twitter: [old_payload, new_payload] } }
    tweetable.manual_publish_to_central(nil, :update, {}, false)
  end
end
