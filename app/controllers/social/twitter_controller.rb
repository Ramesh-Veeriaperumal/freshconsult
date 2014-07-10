class Social::TwitterController < Social::BaseController
  include Social::Stream::Interaction
  include Social::Dynamo::Twitter
  include Social::Twitter::Util
  include Conversations::Twitter
  include Social::Twitter::TicketActions

  before_filter :fetch_live_feeds, :only => [:twitter_search, :show_old, :fetch_new]
  before_filter :set_screen_names, :only => [:reply, :retweet, :create_fd_item]

  def twitter_search
    @recent_search = current_user.agent.recent_social_searches
    respond_to do |format|
      format.js
    end
  end

  def show_old
    respond_to do |format|
      format.js
    end
  end

  def fetch_new
    @refresh = true
    respond_to do |format|
      format.js
    end
  end

  def create_fd_item
    if has_permissions?(params[:search_type], params[:item][:stream_id])
      current_feed = create_fd_item_params
      @current_feed_id = current_feed[:feed_id]
      fd_items = tweet_to_fd_item(current_feed, params[:search_type])
      fd_items.compact!
      @items_info = fd_items.inject([]) do |arr, item|
                    arr << {:feed_id => item.tweet.tweet_id,
                          :link => helpdesk_ticket_link(item),
                          :user_in_db => db_user?(item)  }
                    arr
                end
      flash.now[:notice] = t('twitter.tkt_err_save') if fd_items.empty?
    else
      flash.now[:notice] = t('social.streams.twitter.cannot_create_fd_item')
    end
    respond_to do |format|
      format.js
    end
  end
  
  def user_info
    @user, @interactions =  [{},{}]
    screen_name = params[:user][:screen_name].gsub("@","")
    twt_handle = current_account.random_twitter_handle
    @user[:twitter], @social_error_msg = Social::Twitter::User.fetch(twt_handle, screen_name)
    @user[:image] = (@social_error_msg.blank? ? process_img_url(@user[:twitter].prof_img_url.to_s) : process_img_url(params[:user][:normal_img_url]))
    @user.merge!(
      :screen_name => params[:user][:screen_name],
      :name => params[:user][:name]
    )
    @klout_score = params[:user][:klout_score].to_i # Currently disabling klout score fetching from api
    unless set_screen_names.include?(screen_name)
      @user[:db] = current_account.users.find_by_twitter_id(screen_name,
                                                          :select => "name, customer_id, email, phone, mobile, time_zone")
    end
    visible_stream_ids = User.current.visible_twitter_streams.collect(&:id)
    @interactions = pull_user_interactions(params[:user], visible_stream_ids, SEARCH_TYPE[:saved]) unless visible_stream_ids.blank?
    @user_tickets = user_recent_tickets(screen_name)
    respond_to do |format|
      format.js
    end
  end

  def retweets
    retweeted_id = params[:retweeted_id]
    twt_handle   = current_account.random_twitter_handle
    @retweets, @social_error_msg = Social::Twitter::Feed.fetch_retweets(twt_handle,retweeted_id)
    respond_to do |format|
      format.js
    end
  end

  def reply
    @interactions = {
      :current => []
    }
    params[:twitter_handle] = params[:twitter_handle_id]
    @in_reply_to = params[:tweet][:in_reply_to]
    if has_permissions?(params[:search_type], params[:stream_id])
      tweet        = current_account.tweets.find_by_tweet_id(@in_reply_to)
      unless tweet.blank?
        reply_for_ticket_tweets(tweet)
      else
        reply_for_non_ticket_tweets
      end
    else
      flash.now[:notice] = t('social.streams.twitter.cannot_reply')
    end
    @thumb_avatar_urls = twitter_avatar_urls("thumb")
    @medium_avatar_urls = twitter_avatar_urls("medium")
    respond_to do |format|
      format.js
    end
  end

  def retweet
    @feed_id   = params[:tweet][:feed_id]
    if has_permissions?(params[:search_type], params[:stream_id])
      twt_handle = current_account.twitter_handles.find_by_id(params[:twitter_handle_id])
      retweet_status, @social_error_msg = Social::Twitter::Feed.retweet(twt_handle, @feed_id)
      unless retweet_status.blank?
        flash.now[:notice] = t('social.streams.twitter.retweet_success')
      else
        flash.now[:notice] = @social_error_msg || t('social.streams.twitter.already_retweeted')
      end
    else
      flash.now[:notice] = t('social.streams.twitter.cannot_retweet')
    end
    respond_to do |format|
      format.js
    end
  end
  
  def post_tweet
    if privilege?(:reply_ticket)
      handle_id = params[:twitter_handle_id]
      handle = current_account.twitter_handles.find_by_id(handle_id)
      @tweet_obj, @social_error_msg = Social::Twitter::Feed.post_tweet(handle, params[:tweet][:body])
      unless @tweet_obj.blank?
        flash.now[:notice] = t('social.streams.twitter.tweeted')
      else
        flash.now[:notice] = @social_error_msg
      end
    else
      flash.now[:notice] = t('social.streams.twitter.cannot_post')
    end
    respond_to do |format|
      format.js
    end
  end

  private

  def fetch_live_feeds
    search_type   = params[:search][:type]
    search_params = params[:search]
    twt_handle    = current_account.random_twitter_handle
    
    twt_query = Social::Twitter::Query.new(search_params[:q], search_params[:exclude_keywords], search_params[:exclude_handles])
    fetch_options = {
      :sort_order => :desc,
      :count => LIVE_SEARCH_COUNT
    }
    @all_handles      = current_account.twitter_handles_from_cache
    @all_screen_names = @all_handles.map {|handle| handle.screen_name }
    @social_error_msg, query, @sorted_feeds, @next_results, @refresh_url, next_fetch_id =
      Social::Twitter::Feed.fetch_tweets(twt_handle, search_params, params[:max_id], params[:since_id], fetch_options)
    save_search(search_params, twt_query.query_string) if @social_error_msg.blank? and search_type == SEARCH_TYPE[:live]
    send("populate_fd_info_#{SOURCE[:twitter].downcase}",@sorted_feeds, search_type) unless @sorted_feeds.blank?
  end

  def save_search(search_params, query_string)
    query_string = query_string.gsub("#{TWITTER_RULE_OPERATOR[:ignore_rt]}","")
    search_hash  = {
      "query"        => search_params[:q],
      "handles"      => search_params[:exclude_handles] || [],
      "keywords"     => search_params[:exclude_keywords] || [],
      "query_string" => query_string
    }
    User.current.agent.add_social_search(search_hash)
  end
  
  def has_permissions?(search_type, stream_id)
    return privilege?(:reply_ticket) if (search_type == SEARCH_TYPE[:live] || stream_id.blank?)
    stream  =  current_account.twitter_streams.find_by_id(stream_id.split("#{DELIMITER[:tag_elements]}").last)
    stream_access = (stream ? stream.user_access?(current_user) : false)
    privilege?(:reply_ticket) && stream_access
  end

  def reply_for_ticket_tweets(tweet)
    item   = tweet.get_ticket
    ticket =  item.is_a?(Helpdesk::Ticket) ? item : item.notable
    note = ticket.notes.build(
      :note_body_attributes => {
        :body_html => params[:tweet][:body].strip
      },
      :incoming   => false,
      :private    => false,
      :source     => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:twitter],
      :account_id => current_account.id,
      :user_id    => current_user.id
    )
    saved = note.save_note
    if saved
      twt_success, reply_twt = send_tweet_as_mention(ticket, note)
      if twt_success
        @interactions[:current] << recent_agent_reply(reply_twt, note) if reply_twt
      else
        flash.now[:notice] = t('twitter.not_authorized')
      end
    else
      flash.now[:notice] = t(:'flash.tickets.reply.failure')
    end
  end

  def reply_for_non_ticket_tweets
    twt          = nil
    tweet_text   = validate_tweet(params[:tweet][:body].strip, params[:screen_name])
    in_reply_to  = params[:tweet][:in_reply_to]
    tweet_params = {
      :body           => tweet_text,
      :in_reply_to_id => in_reply_to
    }
    reply_handle = current_account.twitter_handles.find_by_id(params[:twitter_handle_id])
    return_value, @sandbox_error_msg = twt_sandbox(reply_handle) {
      twt = tweet_to_twitter(reply_handle, tweet_params)
      @interactions[:current] << recent_agent_reply(twt, nil) if twt
    }
    if return_value
      if params[:search_type] == SEARCH_TYPE[:saved]
        update_dynamo_for_tweet(twt, in_reply_to, params[:stream_id], nil)
      elsif params[:search_type] == SEARCH_TYPE[:custom]
        reply_params = agent_reply_params(twt, in_reply_to, nil)
        update_custom_streams_reply(reply_params, params[:stream_id], nil)
      end
    else
      flash.now[:notice] = @sandbox_error_msg
    end
  end

  def create_fd_item_params
    {
      :stream_id      => params[:item][:stream_id],
      :feed_id        => params[:item][:feed_id],
      :parent_feed_id => params[:item][:parent_feed_id],
      :name           => params[:item][:user_name],
      :screen_name    => params[:item][:user_screen_name],
      :user_id        => params[:item][:user_id],
      :body           => params[:item][:text],
      :in_reply_to    => params[:item][:in_reply_to],
      :image          => params[:item][:user_image],
      :user_mentions  => params[:item][:user_mentions],
      :posted_time    => params[:item][:posted_time]
    }
  end

  def recent_agent_reply(twt, note)
    feed = Social::Twitter::Feed.new(twt.attrs)
    feed.agent_name = current_user.name
    feed.ticket_id = helpdesk_ticket_link(note) if note
    feed
  end

  def set_screen_names
    @all_handles      = current_account.twitter_handles_from_cache
    @all_screen_names = @all_handles.map {|handle| handle.screen_name }
  end
  
  def db_user?(item)
    item_screen_name = item.is_a?(Helpdesk::Ticket) ? item.requester.twitter_id : item.user.twitter_id
    !@all_screen_names.include?(item_screen_name)
  end
end
