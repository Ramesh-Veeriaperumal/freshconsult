class Social::Stream::TwitterFeed < Social::Stream::Feed

  include Social::Twitter::Util
  include Social::Dynamo::Twitter
  include Social::Twitter::TicketActions

  def initialize(feed_obj)
    @stream_id          = feed_obj[:stream_id][:s]
    @feed_id            = feed_obj[:feed_id][:s]
    @is_replied         = feed_obj[:is_replied][:n].to_i
    @dynamo_posted_time = feed_obj[:posted_time][:ss][0]
    @parent_feed_id     = feed_obj[:parent_feed_id][:ss][0]
    @source             = feed_obj[:source][:s]
    data                = JSON.parse(feed_obj[:data][:ss][0]).symbolize_keys!
    @user = {
      :name        => data[:actor]["displayName"],
      :screen_name => data[:actor]["preferredUsername"],
      :image       => process_img_url(data[:actor]["image"]),
      :id          => data[:actor]["id"] ? data[:actor]["id"].split(":").last : nil,
      :klout_score => data[:gnip] ?  data[:gnip]["klout_score"] : 0
    }
    @user_mentions = process_twitter_entities(data[:twitter_entities])
    @in_reply_to = data[:inReplyTo]["link"].split("/").last if data[:inReplyTo] && data[:inReplyTo]["link"]
    @posted_time = data[:postedTime]
    @body        = data[:body]
    @user_in_db  = true unless feed_obj[:fd_user].nil?
    @in_conv     = feed_obj[:in_conversation][:n].to_i
    @ticket_id   = feed_obj[:fd_link][:ss][0] unless feed_obj[:fd_link].nil?
    @agent_name  = feed_obj[:replied_by][:ss][0] unless feed_obj[:replied_by].nil?
  end

  def convert_to_fd_item(stream, options)
    notable = nil
    handle  = select_reply_handle(stream)
    account = handle.account
    @sender = self.user[:screen_name]
    user    = get_twitter_user(self.user[:screen_name], self.user[:image]["normal"])
    feed_obj, options = fd_item_params(options)

    #HACK for a period of 1 week when we transition from old UI to new UI
    tweet = account.tweets.find_by_tweet_id(self.feed_id)
    if tweet
      notable = tweet.get_ticket
      update_fd_link(self.stream_id, self.feed_id, notable, user)
      return notable
    end

    reply_tweet = account.tweets.find_by_tweet_id(self.in_reply_to)
    unless reply_tweet.blank?
      ticket  = reply_tweet.get_ticket
      notable = add_as_note(feed_obj, handle, :mention, ticket, user, options)
    else
      notable = add_as_ticket(feed_obj, handle, :mention, options) if options[:convert]
    end
    update_fd_link(self.stream_id, self.feed_id, notable, user) if notable
    notable
  end

  def fd_item_params(options)
    feed_obj = {
      :body       => self.body,
      :id         => self.feed_id,
      :postedTime => self.posted_time
    }
    options.merge!(:stream_id => self.stream_id.split("_").last)
    [feed_obj, options]
  end
end
