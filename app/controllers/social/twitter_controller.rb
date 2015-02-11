class Social::TwitterController < Social::BaseController
  include Social::Stream::Interaction
  include Social::Dynamo::Twitter
  include Social::Twitter::Util
  include Conversations::Twitter
  include Social::Twitter::TicketActions
  include Social::Twitter::Constants
  include Mobile::Actions::Social
  include Social::Util

  before_filter :fetch_live_feeds, :only => [:twitter_search, :show_old, :fetch_new]
  before_filter :set_screen_names, :only => [:reply, :retweet, :create_fd_item]
  before_filter :get_favorite_params, :only => [:favorite, :unfavorite]
  before_filter :get_follow_params,   :only => [:follow, :unfollow]
  before_filter :set_native_mobile, :only => [:twitter_search, :show_old, :fetch_new, :reply, :retweet, :post_tweet, :create_fd_item, :favorite, :unfavorite]
  before_filter :load_visible_handles, :only => [:user_info, :followers]
  before_filter :load_reply_handles, :only => [:twitter_search, :show_old, :fetch_new, :reply]


  def twitter_search
    @recent_search = current_user.agent.recent_social_searches
    respond_to do |format|
      format.js { }
      format.nmobile { render_twitter_mobile_response  }
    end
  end

  def show_old
    respond_to do |format|
      format.js { }
      format.nmobile { render_twitter_mobile_response }
    end
  end

  def fetch_new
    @refresh = true
    respond_to do |format|
      format.js { }
      format.nmobile { render_twitter_mobile_response }
    end
  end

  def create_fd_item
    mobile_response = MOBILE_TWITTER_RESPONSE_CODES[:ticket_save]
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
      if fd_items.empty?
        flash.now[:notice] = t('twitter.tkt_err_save')
        mobile_response = MOBILE_TWITTER_RESPONSE_CODES[:tkt_err_save]
      end
    else
      flash.now[:notice] = t('social.streams.twitter.cannot_create_fd_item')
      mobile_response = MOBILE_TWITTER_RESPONSE_CODES[:cannot_create_fd_item]
    end
    respond_to do |format|
      format.js { }
      format.nmobile {
        render :json => { :message => mobile_response,
                          :items => @items_info,
                          :result => !fd_items.empty?
                        }
      }
    end
  end
  
  def user_info
    @user, @interactions =  [{},{}]
    screen_name = params[:user][:screen_name].gsub("@","")
    twt_handle = current_account.random_twitter_handle
    @social_error_msg, @user[:twitter] = Social::Twitter::User.fetch(twt_handle, screen_name)
    @user[:image] = (@social_error_msg.blank? ? process_img_url(@user[:twitter].prof_img_url.to_s) : process_img_url(params[:user][:normal_img_url]))
    @user.merge!(
      :screen_name => params[:user][:screen_name],
      :name => params[:user][:name]
    )
    @klout_score = params[:user][:klout_score].to_i # Currently disabling klout score fetching from api
    @user[:show_followers] = true unless visible_screen_names == [screen_name]
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
    @social_error_msg , @retweets = Social::Twitter::Feed.fetch_retweets(twt_handle,retweeted_id)
    respond_to do |format|
      format.js
    end
  end
  
  #Following method will check requester is a follower of responding twitter Id
  def user_following
    user_follows = false
    reply_handle = current_account.twitter_handles.find(params[:twitter_handle])
    unless reply_handle.nil?
      @social_error_msg , user_follows = Social::Twitter::Feed.following?(reply_handle, params[:req_twt_id])
    end
    
    user_following = @social_error_msg.blank? ? (user_follows ? user_follows : t('ticket.tweet_form.user_not_following')): t('twitter.not_authorized')
    render :json => {:user_follows => user_following }.to_json
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
        mobile_response = reply_for_ticket_tweets(tweet)
      else
        mobile_response = reply_for_non_ticket_tweets
      end
    else
      flash.now[:notice] = t('social.streams.twitter.cannot_reply')
      mobile_response = MOBILE_TWITTER_RESPONSE_CODES[:cannot_reply]
    end
    @thumb_avatar_urls = twitter_avatar_urls("thumb")
    @medium_avatar_urls = twitter_avatar_urls("medium")
    respond_to do |format|
      format.js { }
      format.nmobile {
        render :json => { :message => mobile_response,
                          :result =>  mobile_response.eql?(MOBILE_TWITTER_RESPONSE_CODES[:reply_success]) }
      }
    end
  end

  def retweet
    @feed_id   = params[:tweet][:feed_id]
    if has_permissions?(params[:search_type], params[:stream_id])
      twt_handle = current_account.twitter_handles.find_by_id(params[:twitter_handle_id])
      @social_error_msg, retweet_status = Social::Twitter::Feed.twitter_action(twt_handle, @feed_id, TWITTER_ACTIONS[:retweet])
      unless retweet_status.blank?
        flash.now[:notice] = t('social.streams.twitter.retweet_success')
        mobile_response = MOBILE_TWITTER_RESPONSE_CODES[:retweet_success]
      else
        flash.now[:notice] = @social_error_msg || t('social.streams.twitter.already_retweeted')
        mobile_response = MOBILE_TWITTER_RESPONSE_CODES[:already_retweeted]
      end
    else
      flash.now[:notice] = t('social.streams.twitter.cannot_retweet')
      mobile_response = MOBILE_TWITTER_RESPONSE_CODES[:cannot_retweet]
    end
    respond_to do |format|
      format.js { }
      format.nmobile {
        render :json => { :message => mobile_response,
                          :result =>  !retweet_status.blank? }
      }
    end
  end
  
  def favorite
    mobile_response = MOBILE_TWITTER_RESPONSE_CODES[:favorite_success]
    if has_permissions?(params[:search_type], @stream_id)
      twt_handle = @stream.twitter_handle unless @stream.nil?
      @social_error_msg, favourite_status = Social::Twitter::Feed.twitter_action(twt_handle, @feed_id, TWITTER_ACTIONS[:favorite])
      update_favorite_in_dynamo(@stream_id, @feed_id, 1) if @social_error_msg.nil? 
      if favourite_status.blank?
        flash.now[:notice] = @social_error_msg if @social_error_msg
        mobile_response = MOBILE_TWITTER_RESPONSE_CODES[:favorite_error]
      end
    else
      flash.now[:notice] = t('social.streams.twitter.cannot_favorite')
      mobile_response = MOBILE_TWITTER_RESPONSE_CODES[:cannot_favorite]
    end

    respond_to do |format|
      format.js
      format.nmobile {
        render :json => { :message => mobile_response,
                          :feed_id => @feed_id,
                          :result =>  !favourite_status.blank? }
      }
    end
  end
  
  def unfavorite
    mobile_response = MOBILE_TWITTER_RESPONSE_CODES[:unfavorite_success]
    if has_permissions?(params[:search_type], @stream_id)
      twt_handle = @stream.twitter_handle unless @stream.nil?
      @social_error_msg, unfavourite_status = Social::Twitter::Feed.twitter_action(twt_handle, @feed_id, TWITTER_ACTIONS[:unfavorite])
      update_favorite_in_dynamo(@stream_id, @feed_id, 0) if not_valid_error?(@social_error_msg)
      if unfavourite_status.blank? 
        flash.now[:notice] = @social_error_msg unless not_valid_error?(@social_error_msg)
        mobile_response = MOBILE_TWITTER_RESPONSE_CODES[:unfavorite_error]
      end
    else
      flash.now[:notice] = t('social.streams.twitter.cannot_unfavorite')
      mobile_response = MOBILE_TWITTER_RESPONSE_CODES[:cannot_unfavorite]
    end

    respond_to do |format|
      format.js
      format.nmobile {
        render :json => { :message => mobile_response,
                          :feed_id => @feed_id,
                          :result =>  !unfavourite_status.blank? }
      }
    end
  end
  
  def followers
    screen_name = params[:screen_name].gsub("@","")
    twt_handle  = current_account.random_twitter_handle
    @social_error_msg, follower_ids = Social::Twitter::User.get_followers(twt_handle, screen_name)
    if @social_error_msg.blank? and !follower_ids.nil?
      visible_handles  = @visible_handles.select {|handle| handle.screen_name != screen_name }
      @follow_hash = Hash[*visible_handles.collect { |handle| [ handle.screen_name, following?(follower_ids, handle.twitter_user_id) ] }.flatten]
    else
      flash.now[:notice] = @social_error_msg
    end
    
    respond_to do |format|
      format.js
    end
  end
  
  def follow
    if has_permissions?(params[:search_type], @stream_id)
      twt_handle = current_account.twitter_handles.find_by_screen_name(@screen_name)
      @social_error_msg, follow_status = Social::Twitter::Feed.twitter_action(twt_handle, @screen_name_to_follow, TWITTER_ACTIONS[:follow])
      if follow_status.blank?
        flash.now[:notice] = @social_error_msg || t('social.streams.twitter.already_followed')         
      else
        flash.now[:notice] = t('social.streams.twitter.follow_success') 
      end
    else
      flash.now[:notice] = t('social.streams.twitter.cannot_follow')
    end
    
    respond_to do |format|
      format.js
    end
  end
  
  def unfollow
    if has_permissions?(params[:search_type], @stream_id)
      twt_handle = current_account.twitter_handles.find_by_screen_name(@screen_name)
      @social_error_msg, unfollow_status = Social::Twitter::Feed.twitter_action(twt_handle, @screen_name_to_follow, TWITTER_ACTIONS[:unfollow])
      if unfollow_status.blank?
        flash.now[:notice] = @social_error_msg || t('social.streams.twitter.already_unfollowed') 
      else
        flash.now[:notice] = t('social.streams.twitter.unfollow_success')        
      end
    else
      flash.now[:notice] = t('social.streams.twitter.cannot_unfollow')
    end
    
    respond_to do |format|
      format.js
    end
  end
  
  def post_tweet
    handle_id = params[:twitter_handle_id]
    handle = current_account.twitter_handles.find_by_id(handle_id)
    stream_id = handle.default_stream.dynamo_stream_id
    if has_permissions?(SEARCH_TYPE[:saved], stream_id)
      error_message, twt_text = validate_tweet(params[:tweet][:body].strip, nil, false)
      
      if error_message.blank?
        @social_error_msg, @tweet_obj = Social::Twitter::Feed.twitter_action(handle, twt_text, TWITTER_ACTIONS[:post_tweet])
        unless @tweet_obj.blank?
          flash.now[:notice] = t('social.streams.twitter.tweeted')
          mobile_response = MOBILE_TWITTER_RESPONSE_CODES[:tweeted]
        else
          flash.now[:notice] = @social_error_msg
          mobile_response = MOBILE_TWITTER_RESPONSE_CODES[:social_error_msg]
        end
      else
        flash.now[:notice] = error_message
        mobile_response = MOBILE_TWITTER_RESPONSE_CODES[:validation_failed]
      end
      
    else
      flash.now[:notice] = t('social.streams.twitter.cannot_post')
      mobile_response = MOBILE_TWITTER_RESPONSE_CODES[:cannot_post]
    end
    respond_to do |format|
      format.js { }
      format.nmobile {
        render :json => { :message => mobile_response,
                          :result =>  !@tweet_obj.blank? }
      }
    end
  end

  private
  
  def not_valid_error?(social_error_msg)
    social_error_msg.nil? or social_error_msg == "#{I18n.t('social.streams.twitter.wrong_call')}"
  end
  
  def get_favorite_params
    @stream_id = params[:item][:stream_id]
    @feed_id   = params[:item][:feed_id]
    @stream    = current_account.twitter_streams.find_by_id(@stream_id.split("#{DELIMITER[:tag_elements]}").last)
  end
  
  def get_follow_params
    @stream_id   = params[:user][:stream_id] 
    @screen_name_to_follow = params[:user][:to_follow].gsub("@","")
    @screen_name = params[:user][:screen_name]
  end
  
  def following?(accounts_following, handle_id)
    accounts_following.include?(handle_id)
  end
  
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
    error_message, tweet_body = validate_tweet(params[:tweet][:body].strip, "@#{params[:screen_name]}")
    if error_message.blank?
      item   = tweet.get_ticket
      ticket =  item.is_a?(Helpdesk::Ticket) ? item : item.notable
      note = ticket.notes.build(
        :note_body_attributes => {
          :body_html => tweet_body
        },
        :incoming   => false,
        :private    => false,
        :source     => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:twitter],
        :account_id => current_account.id,
        :user_id    => current_user.id
      )
      saved = note.save_note
      if saved
        error_message, reply_twt = send_tweet_as_mention(ticket, note, tweet_body)
        if error_message.blank?
          @interactions[:current] << recent_agent_reply(reply_twt, note) if reply_twt
          MOBILE_TWITTER_RESPONSE_CODES[:reply_success]
        else
          flash.now[:notice] = error_message
          MOBILE_TWITTER_RESPONSE_CODES[:not_authorized]
        end
      else
        flash.now[:notice] = t(:'flash.tickets.reply.failure')
        MOBILE_TWITTER_RESPONSE_CODES[:reply_failure]
      end
    else
      flash.now[:notice] = error_message
      MOBILE_TWITTER_RESPONSE_CODES[:validation_failed]
    end
  end

  def reply_for_non_ticket_tweets
    twt          = nil
    error_message, tweet_text = validate_tweet(params[:tweet][:body].strip, "@#{params[:screen_name]}")
    if error_message.blank?
      in_reply_to  = params[:tweet][:in_reply_to]
      tweet_params = {
        :body           => tweet_text,
        :in_reply_to_id => in_reply_to
      }
      reply_handle = current_account.twitter_handles.find_by_id(params[:twitter_handle_id])
      @sandbox_error_msg, return_value = twt_sandbox(reply_handle) {
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
        MOBILE_TWITTER_RESPONSE_CODES[:reply_success]
      else
        flash.now[:notice] = @sandbox_error_msg
        MOBILE_TWITTER_RESPONSE_CODES[:sandbox_error_msg]
      end
    else
      flash.now[:notice] = error_message
      MOBILE_TWITTER_RESPONSE_CODES[:validation_failed]
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
  
  def visible_screen_names
    @visible_handles.map{|handle| handle.screen_name}
  end
  
  def db_user?(item)
    item_screen_name = item.is_a?(Helpdesk::Ticket) ? item.requester.twitter_id : item.user.twitter_id
    !@all_screen_names.include?(item_screen_name)
  end
end
