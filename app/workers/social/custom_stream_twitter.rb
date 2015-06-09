class Social::CustomStreamTwitter
   
  def initialize(msg)
    account = Account.current
    twitter_streams = account.twitter_streams
    if msg[:stream_id]
      streams = [twitter_streams.find_by_id(msg[:stream_id])]
    else
      streams = select_non_gnip_streams(twitter_streams)
    end
    streams.compact!
    process_streams(streams)
  end
   
  private
  def process_streams(twitter_streams)
    account = Account.current
    twitter_streams.each do |stream|
      query_hash = {
        :q                => stream.includes,
        :exclude_keywords => stream.excludes,
        :exclude_handles  => stream.filter[:exclude_twitter_handles],
        :type             => Social::Constants::SEARCH_TYPE[:custom]
      }
      since_id = stream.data[:since_id]
      handle = account.random_twitter_handle
      fetch_options = {
        :sort_order => :asc,
        :count => Social::Twitter::Constants::MAX_SEARCH_RESULTS_COUNT
      }
      error_msg, query, feeds, next_results, refresh_url, next_fetch_id =
        Social::Twitter::Feed.fetch_tweets(handle, query_hash, nil, since_id, fetch_options)
      
      process_stream_feeds(feeds, stream, next_fetch_id) if error_msg.blank? && feeds.length > 0
    end
  end  
  
  def process_stream_feeds(feeds, stream, next_fetch_id)
    update_since_id(stream, next_fetch_id)
    feeds.each do |feed|
      fd_item = apply_ticket_rules(stream, feed)
      if stream.default_stream?
        account_id = stream.account_id
        handle = stream.twitter_handle
        twt_user = feed.user[:screen_name]
        body = feed.body
        feed.stream_id = stream.id
        feed.ticket_id = helpdesk_ticket_link(fd_item) if fd_item
        feed.push_to_dynamo(account_id, self_tweeted?(twt_user, handle), self_tweeted_with_mention?(twt_user, handle, body))
      end
    end
  end
    
  def update_since_id(stream, next_fetch_id)
    if next_fetch_id
      stream.data.update(:since_id => next_fetch_id)
      stream.save
    end
  end
  
  def apply_ticket_rules(stream, feed)
    hash = stream.check_ticket_rules(feed.body)
    hash.merge!(:tweet => true)
    notable = feed.convert_to_fd_item(stream, hash)
  end
  
  def select_non_gnip_streams(twitter_streams)
    twitter_streams.select {|stream| (stream.custom_stream? && !stream.ticket_rules.blank?) || non_gnip_default_stream(stream) }
  end
  
  def non_gnip_default_stream(stream)
    (stream.default_stream? && !stream.gnip_subscription?)
  end
  
  def self_tweeted_with_mention?(twt_user, handle, body)
    self_tweeted?(twt_user, handle) && body.include?(handle.formatted_handle)
  end
  
  def self_tweeted?(twt_user, handle)
    twt_user.downcase.strip().eql?(handle.screen_name.downcase.strip)
  end
  
  def helpdesk_ticket_link(item) # duplicate method from social util
    return nil if item.nil? or item.id.nil? #if the ticket/note save failed or we requeue the feed
    if item.is_a?(Helpdesk::Ticket)
      link = "#{item.display_id}"
    elsif item.is_a?(Helpdesk::Note)
      ticket = item.notable
      link = "#{ticket.display_id}#note#{item.id}"
    end
  end
  
end
