class Social::Twitter::Mention

  attr_accessor :twitter, :twt_handle
  include Social::Twitter::TicketActions

  #TODO @ARV : reorg this similar to Twitter:Feed where process is a class function and we create objects of type Mention

  def initialize(twt_handle, options = {})
    wrapper         = TwitterWrapper.new twt_handle
    self.twitter    = wrapper.get_twitter
    self.twt_handle = twt_handle
  end

  def process
    tweets = twt_handle.last_mention_id.blank? ? twitter.mentions : twitter.mentions({:since_id =>twt_handle.last_mention_id})
    last_tweet_id = tweets[0].id unless tweets.blank?
    create_ticket_from_mention(tweets ,twt_handle)
    twt_handle.update_attribute(:last_mention_id, last_tweet_id) unless last_tweet_id.blank?
  end

  def create_ticket_from_mention(tweets, twt_handle)
    tweets.each do |twt|
      @sender = twt.user
      account = twt_handle.account
      user   = get_twitter_user(@sender.screen_name)

      if twt.in_reply_to_status_id.blank?
        add_as_ticket twt , twt_handle , :mention, {}, nil, user
      else
        tweet = account.tweets.find_by_tweet_id(twt.in_reply_to_status_id)
        unless tweet.blank?
          ticket = tweet.get_ticket
          add_as_note twt , twt_handle , :mention , ticket, user
        else
          add_as_ticket twt , twt_handle , :mention, {}, nil, user
        end
      end
    end
  end

  # for fetching the tweets manually in case of any failures
  # options can have since_id or max_id along with the count
  def manual_fetch(options)
    tweets = twitter.mentions(options)
    create_ticket_from_mention(tweets,twt_handle) unless tweets.blank?
  end

end
