class Social::Twitter::Feed

  include Gnip::Constants
  include Social::Constants
  include Social::Dynamo::Twitter
  include Social::Twitter::Constants
  include Social::Twitter::Util
  include Social::Twitter::ErrorHandler
  include Social::Twitter::TicketActions

  attr_accessor :feed_id, :posted_time, :user, :body, :is_replied, :ticket_id, :user_in_db, :dynamo_posted_time,
    :in_reply_to, :stream_id, :in_conv, :agent_name,:source, :parent_feed_id, :user_mentions


  def initialize(feed_obj)
    @stream_id      = feed_obj[:stream_id]
    @feed_id        = feed_obj[:id_str]
    @parent_feed_id = feed_obj[:id_str]
    @dynamo_posted_time = Time.parse("#{feed_obj[:created_at]}").to_i
    @posted_time = Time.at(@dynamo_posted_time).utc.strftime("%FT%T.000Z")
    @user = {
      :name            => feed_obj[:user][:name],
      :screen_name     => feed_obj[:user][:screen_name],
      :image           => process_img_url(feed_obj[:user][:profile_image_url]),
      :id              => feed_obj[:user][:id_str],
      :followers_count => feed_obj[:user][:followers_count],
      :klout_score     => 0
    }
    @user_mentions = process_twitter_entities(feed_obj[:entities])
    @body        = feed_obj[:text]
    @source      = SOURCE[:twitter]
    @in_reply_to = feed_obj[:in_reply_to_status_id_str]
    @ticket_id   = feed_obj[:ticket_id]
    @is_replied  = 0
    @user_in_db  = false
    @in_conv     = 0
    @agent_name  = false
  end

  def convert_to_fd_item(stream, action_data)
    notable = nil
    handle  = select_reply_handle(stream)
    account = handle.account
    @sender = self.user[:screen_name]
    feed_obj = {
      :body       => self.body,
      :id         => self.feed_id,
      :postedTime => self.posted_time
    }
    action_data.merge!(:stream_id => stream.id) if stream
    tweet = account.tweets.find_by_tweet_id(self.in_reply_to)
    unless tweet.blank?
      ticket = tweet.get_ticket
      user = get_twitter_user(self.user[:screen_name], self.user[:image]["normal"])
      notable  = add_as_note(feed_obj, handle, :mention, ticket, user, action_data)
    else
      if action_data[:convert]
        user = get_twitter_user(self.user[:screen_name], self.user[:image]["normal"])
        notable = add_as_ticket(feed_obj, handle, :mention, action_data) 
      end
    end
    notable
  end
  
  def push_to_dynamo(account_id, tweeted, tweeted_with_mention)
    screen_names_hash = {}
    posted_time = Time.parse(self.posted_time)
    args = {
      :stream_id => self.stream_id,
      :account_id => account_id,
      :tweeted => tweeted,
      :tweeted_with_mention => tweeted_with_mention
    }
    if self.user_mentions
      screen_names_hash = self.user_mentions.map {|mention| {:screen_name => mention} }
    end
    dynamo_params = {
      :id => self.feed_id,
      :body => self.body,
      :ticket_id => self.ticket_id,
      :posted_at => self.posted_time,
      :user => self.user,
      :user_mentions => screen_names_hash 
    }
    update_live_feed(posted_time, args, dynamo_params, self )
  end

  def self.fetch_tweets(handle, search_params, max_id, since_id, options)
    query = feeds = next_results = refresh_url = next_fetch_id = nil
    sorted_feeds = []
    error_msg, response = search(handle, search_params, max_id, since_id, options) # TODO Handle the case if response is nil due to rate limiting
    if response
      query         = response.attrs[:search_metadata][:query]
      next_results  = (response.attrs[:search_metadata][:next_results] ? response.attrs[:search_metadata][:next_results] : response.attrs[:search_metadata][:refresh_url])
      refresh_url   = response.attrs[:search_metadata][:refresh_url]
      next_fetch_id = response.attrs[:search_metadata][:max_id_str]
      feeds = response.attrs[:statuses].inject([]) do |arr, status|
        stream_id = "#{Account.current.id}_#{search_params[:stream_id]}" if search_params[:stream_id]
        status.merge!(:stream_id => stream_id)
        feed = Social::Twitter::Feed.new(status)
        arr << feed
        arr
      end
      sorted_feeds = sort(feeds, options[:sort_order])
    end
    return [error_msg, query, sorted_feeds, next_results, refresh_url, next_fetch_id]
  end

  def self.fetch_retweets(handle, feed_id)
    return {:count => 0, :status => nil, :feeds => []} if feed_id.blank?
    twt_sandbox(handle) do
      twitter = TwitterWrapper.new(handle).get_twitter
      status = twitter.status("#{feed_id}")
      original_feed = Social::Twitter::Feed.new(status.attrs)
      retweet_count = status[:retweet_count].to_i
      retweeted_feeds = retweet_count > 0  ? retweets(twitter, feed_id) : []
      {:count => retweet_count, :feeds => retweeted_feeds, :status => original_feed }
    end
  end

  def self.twitter_action(handle, param, action)
    return if param.blank?
    twt_sandbox(handle) do
      twitter = TwitterWrapper.new(handle).get_twitter
      action_response = twitter.send(action, "#{param}")
    end
  end   
  
  def self.following?(handle, req_twt_id)
    return if req_twt_id.blank?
    twt_sandbox(handle) do
      twitter = TwitterWrapper.new(handle).get_twitter
      user_follows = twitter.friendship?(req_twt_id, handle.screen_name)
    end
  end  

  private
  
  def self.retweets(twitter, feed_id)
    results       = twitter.retweets("#{feed_id}", :count => RETWEETS_COUNT)
    retweet_feeds = results.inject([]) { |arr, result| arr << Social::Twitter::Feed.new(result.attrs); arr }
  end

  def self.search(handle, search_params, max_id, since_id, options)
    twt_query = Social::Twitter::Query.new(search_params[:q], search_params[:exclude_keywords], search_params[:exclude_handles])
    query     = twt_query.query_string

    twt_sandbox(handle, TWITTER_TIMEOUT[:search]) do
      wrapper = TwitterWrapper.new handle
      twitter = wrapper.get_twitter
      if max_id
        options.merge!({:max_id => max_id})
      elsif since_id
        options.merge!({:since_id => since_id})
      end
      twitter.search(query, options)
    end
  end
  
  def self.sort(results, order)
    results = results.reject(&:blank?)
    results.flatten!
    sorted_results = results.sort_by { |result| result.dynamo_posted_time.to_i }
    order == :desc ? sorted_results.reverse! : sorted_results
  end

end
