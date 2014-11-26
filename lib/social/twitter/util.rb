module Social::Twitter::Util

  include Social::Twitter::Constants
  include Social::Constants

  def user_recent_tickets(screen_name)
    requester = Account.current.users.find_by_twitter_id(screen_name, :select => "id")
    tickets = Account.current.tickets.requester_active(requester).visible.newest(3).find(:all) if requester
  end

  def populate_fd_info_twitter(feeds, search_type)
    all_handle_screen_names = Account.current.twitter_handles_from_cache.collect(&:screen_name)
    screen_names = feeds.inject([]) { |arr, feed| arr << feed.user[:screen_name]; arr}
    db_users     = Account.current.users.find(:all,
                                              :select => "twitter_id",
                                              :conditions => {:twitter_id => screen_names.uniq})
    screen_names_in_db = db_users.collect(&:twitter_id)

    if non_brand_streams?(search_type)
      tweet_ids  = feeds.collect(&:feed_id)
      db_tweets = Account.current.tweets.find(:all,
                                              :select => "tweet_id, tweetable_id, tweetable_type",
                                              :conditions => { :tweet_id => tweet_ids.uniq },
                                              :include => :tweetable)
      tkt_hash = db_tweets.inject({}) {| hash, tweet|  hash.store(tweet.tweet_id, helpdesk_ticket_link(tweet.tweetable)); hash}
    end

    # To display the crown icon, we check in our db if the user is present or not (even if "fd_user" attribute is set)
    # TODO optimize such that you hit our db only if the "fd_user" attribute is not set for the corresponding feed object in Dynamo
    if !screen_names_in_db.blank? || (non_brand_streams?(search_type) && !tkt_hash.blank?)
      feeds.each do |feed|
        feed.user_in_db = fd_user?(screen_names_in_db, feed.user[:screen_name], all_handle_screen_names)
        feed.ticket_id  = tkt_hash[feed.feed_id.to_i]  if non_brand_streams?(search_type) && tkt_hash.has_key?(feed.feed_id.to_i)
      end
    end
  end

  def fd_user?(db_screen_names, current_screen_name, all_handle_screen_names)
    db_screen_names.include?(current_screen_name) && !all_handle_screen_names.include?(current_screen_name)
  end

  def non_brand_streams?(search_type)
    (search_type == SEARCH_TYPE[:live] || search_type == SEARCH_TYPE[:custom])
  end

  def select_reply_handle(stream)
    handle = stream.twitter_handle unless stream.nil?
    handle = Account.current.twitter_handles.first if stream.nil? || handle.nil?
    handle
  end

  def process_twitter_entities(twitter_entities)
    return [] if twitter_entities.blank?
    return_symbolized_keys!(twitter_entities)
    user_mentions_hash = twitter_entities[:user_mentions]
    mentions = (user_mentions_hash ? user_mentions_hash.map { |mention| mention[:screen_name] }  : [])
  end

  def return_symbolized_keys!(h)
    h.symbolize_keys!
    h.each do |k, v|
      v.each do |k1, v1|
        k1.symbolize_keys! if k1.is_a? Hash
      end
    end
  end

  def process_img_url(fetched_url)
    return fetched_url if fetched_url.is_a?(Hash)
    ext = File.extname(fetched_url)
    url_without_ext = fetched_url.chomp(ext)
    AVATAR_SIZES.any?{|size| url_without_ext.gsub!(/_#{size}$/,"") }
    img_urls = AVATAR_SIZES.inject({}) do |hash, size|
                  hash[size] = "#{url_without_ext}_#{size}#{ext}"
                  hash
              end
  end
  
  def load_reply_handles
    @reply_handles = all_visible_streams.map{ |stream| stream.twitter_handle}.compact.uniq
  end
  
  def load_visible_handles
    @visible_handles = all_visible_streams.map{ |stream| stream.twitter_handle if stream.default_stream?}.compact
  end
  
  def all_visible_streams
    @all_visible_streams ||= current_user.visible_social_streams
  end

end
