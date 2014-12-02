class Social::StreamsController < Social::BaseController

  include Social::Twitter::Util
  include Social::Dynamo::Twitter
  include Social::Stream::Interaction
  include Mobile::Actions::Social

  before_filter { |c| c.requires_feature :twitter }
  skip_before_filter :check_account_state
  before_filter :check_account_state
  before_filter :check_if_handles_exist, :only => [:index]
  before_filter :set_native_mobile, :only => [:stream_feeds, :show_old, :fetch_new, :interactions]
  before_filter :set_stream_params, :only => [:stream_feeds], :if => :is_mobile_meta_request?
  before_filter :load_reply_handles, :only => [:index, :stream_feeds, :show_old, :fetch_new, :interactions]

  def index
    set_stream_params
    @selected_tab = :social
  end

  def stream_feeds
    range_and_hash_keys = construct_hash_and_range_key(STREAM_FEEDS_ACTION_KEYS[:index])
    @sorted_feeds = fetch_feeds(range_and_hash_keys)
    @recent_search = current_user.agent.recent_social_searches
    respond_to do |format|
      format.js { }
      format.nmobile { render_mobile_response }
    end
  end

  def show_old
    range_and_hash_keys = construct_hash_and_range_key(STREAM_FEEDS_ACTION_KEYS[:show_old])
    @sorted_feeds = fetch_feeds(range_and_hash_keys)
    respond_to do |format|
      format.js { }
      format.nmobile { render_mobile_response }
    end
  end

  def fetch_new
    range_and_hash_keys = construct_hash_and_range_key(STREAM_FEEDS_ACTION_KEYS[:fetch_new])
    @sorted_feeds = fetch_feeds(range_and_hash_keys)
    @refresh = true
    respond_to do |format|
      format.js { }
      format.nmobile { render_mobile_response }
    end
  end

  def interactions
    current_feed_info = interaction_params
    search_type       = params[:search_type]
    @is_retweet       = params[:is_retweet].to_bool
    @is_reply         = params[:is_reply].to_bool
    @feed_id          = params[:social_streams][:feed_id]
    @user_tickets     = user_recent_tickets(current_feed_info[:screen_name])
    @interactions     = pull_interactions(current_feed_info, search_type)

    @name = current_feed_info[:name].split.first
    @all_handles      = current_account.twitter_handles_from_cache
    @all_screen_names = @all_handles.map {|handle| handle.screen_name }
    @thumb_avatar_urls = twitter_avatar_urls("thumb")
    @medium_avatar_urls = twitter_avatar_urls("medium")
    respond_to do |format|
      format.js { }
      format.nmobile {
        render :json => @interactions
      }
    end
  end

  private

  def fetch_feeds(range_and_hash_keys)
    feeds         = Social::Stream::Feed.fetch(range_and_hash_keys)
    sorted_feeds = []
    unless feeds.blank?
      meta_data       = feeds_meta_data(feeds)
      @first_feed_ids = meta_data.values.map {|data| data[:first_feed_id] }.join(",")
      @last_feed_ids  = meta_data.values.map {|data| data[:last_feed_id] }.join(",")
      @stream_ids     = @valid_stream_ids.join(",")
      sorted_feeds   = feeds.take(NUM_RECORDS_TO_DISPLAY)
      twitter_feeds   = sorted_feeds.select{ |feed| feed.source.eql?(SOURCE[:twitter]) }
      send("populate_fd_info_#{SOURCE[:twitter].downcase}", twitter_feeds, SEARCH_TYPE[:saved])
    end
    @all_handles      = current_account.twitter_handles_from_cache
    @all_screen_names = @all_handles.map {|handle| handle.screen_name }
    sorted_feeds
  end

  def feeds_meta_data(feeds)
    streams_hash = {}
    streams_hash = @valid_stream_ids.inject({}) do |hash,arr|
      hash["#{current_account.id}_#{arr}"] = {:first_feed_id => 0, :last_feed_id => 0}
      hash
    end

    feeds.each_with_index do |feed, index|
      stream_id   = feed.stream_id
      feed_id     = feed.feed_id
      stream_hash = streams_hash[stream_id]

      if index < NUM_RECORDS_TO_DISPLAY
        stream_hash[:first_feed_id] = feed_id if stream_hash[:first_feed_id] == 0
        stream_hash[:last_feed_id]  = feed_id
      else # for index > no of records
        if stream_hash[:first_feed_id] == 0
          stream_hash[:first_feed_id] = feed_id.to_i
          stream_hash[:last_feed_id]  = feed_id.to_i + 1
        end
      end
      streams_hash[stream_id] = stream_hash
    end
    @valid_stream_ids.each_with_index do |stream_id, index|
      if streams_hash["#{current_account.id}_#{stream_id}"][:first_feed_id] == 0
        streams_hash["#{current_account.id}_#{stream_id}"] = {
          :first_feed_id => @first_ids[index],
          :last_feed_id  => @last_ids[index]
        }
      end
    end
    return streams_hash
  end

  def construct_hash_and_range_key(action)
    keys              = []
    @valid_stream_ids = validate_streams(action)
    @first_ids        = params[:social_streams][:first_feed_id].split(",")
    @last_ids         = params[:social_streams][:last_feed_id].split(",")
    operator          = (action == STREAM_FEEDS_ACTION_KEYS[:show_old]) ? "LT" : "GT"

    @valid_stream_ids.each_with_index do |stream_id, index|
      hash_key  = "#{current_account.id}_#{stream_id}"
      range_key =  build_range_key(operator, index)
      keys << {:hash_key => hash_key, :operator => operator, :range_key => range_key}
    end
    keys
  end

  def build_range_key(operator, index)
    key = (operator == "LT") ? @last_ids[index] : @first_ids[index]
  end

  def interaction_params
    {
      :stream_id      => params[:social_streams][:stream_id],
      :feed_id        => params[:social_streams][:feed_id],
      :user_id        => params[:social_streams][:user_id],
      :name           => params[:social_streams][:user_name],
      :screen_name    => params[:social_streams][:user_screen_name],
      :body           => params[:social_streams][:text],
      :posted_time    => params[:social_streams][:posted_time],
      :image          => params[:social_streams][:user_image],
      :parent_feed_id => params[:social_streams][:parent_feed_id],
      :user_mentions => params[:social_streams][:user_mentions]
    }
  end

  def validate_streams(action)
    streams = params[:social_streams][:stream_id].split(",")
    return streams if (action == STREAM_FEEDS_ACTION_KEYS[:show_old] || action == STREAM_FEEDS_ACTION_KEYS[:fetch_new])
    visible_stream_ids = current_user.visible_social_streams.map { |stream| "#{stream.id}" }
    streams & visible_stream_ids
  end

  def check_if_handles_exist
    if current_account.twitter_handles.blank?
      flash[:notice] = t('no_twitter_handle')
      redirect_to admin_social_streams_url
    end
  end

  def set_stream_params
    load_visible_handles
    @streams        = all_visible_streams.select { |stream| stream.default_stream? }
    @custom_streams = all_visible_streams.select { |stream| stream.custom_stream? }
    @all_handles      = current_account.twitter_handles_from_cache
    @thumb_avatar_urls = twitter_avatar_urls("thumb") # reorg the avatar urls - make as a function
    @medium_avatar_urls = twitter_avatar_urls("medium")
    @recent_search = current_user.agent.recent_social_searches
    @meta_data      = []
    @streams.each do |stream|
      @meta_data << {
        :stream_id => "#{stream.id}",
        :first_feed_id => 0,
        :last_feed_id => 0
      }
    end
    if is_native_mobile?
      params[:social_streams] = {}
      params[:social_streams][:stream_id] = @streams.map { |stream| stream.id }.join(",")
      params[:social_streams][:first_feed_id] = Array.new(@streams.count, 0).join(",")
      params[:social_streams][:last_feed_id] = Array.new(@streams.count, 0).join(",")
    end
  end
end
