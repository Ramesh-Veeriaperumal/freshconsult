class Social::WelcomeController < ApplicationController
  
  include Social::Twitter::Constants
  
  before_filter :can_view_welcome_page?, :only => [:index]
  
  def index
    @selected_tab = :social
    acc_add_settings = current_account.account_additional_settings
    additional_settings = acc_add_settings.additional_settings if acc_add_settings.attributes.keys.include?("additional_settings")
    @twitter_enable = (additional_settings.nil? ||  additional_settings[:enable_social]) 
  end

  def get_stats
    handle = params[:twitter_handle]
    handle = handle.gsub(/^@/,'')
    customer_tweets_list = customer_tweets(handle)
    customer_tweets_replied = replied_customer_tweets(customer_tweets_list, handle)
    customer_tweets = customer_tweets_list.length
    replied_tweets = customer_tweets_replied.length
    perct = (replied_tweets.to_f / customer_tweets.to_f) * 100
    @perct = perct.nan? ? 0 : perct.truncate
    respond_to do |format|
      format.js
    end
  end

  def enable_feature
    feature = params[:twitter] == "true" ? true : false
    account_additional_settings = current_account.account_additional_settings
    unless account_additional_settings.additional_settings.nil?
      account_additional_settings.additional_settings[:enable_social] = feature
      account_additional_settings.save
    else
      additional_settings = {
          :enable_social => feature
      }
      account_additional_settings.update_attributes(:additional_settings => additional_settings)
    end
    render :nothing => true
  end

  private
  def twitter_client
    client = OAuth2::Client.new(TwitterConfig::CLIENT_ID, TwitterConfig::CLIENT_SECRET, :site => 'https://api.twitter.com', :authorize_url => '/oauth2/authorize', :token_url=>"/oauth2/token")
    params = {'grant_type' => 'client_credentials', "client_id" => TwitterConfig::CLIENT_ID, "client_secret" => TwitterConfig::CLIENT_SECRET}
    opts   = {'refresh_token' => nil}
    client.get_token(params, opts)
  end

  def brand_tweets(handle)
    brand_tweets = fetch_tweets("#{TWITTER_RULE_OPERATOR[:from]}#{handle} #{TWITTER_RULE_OPERATOR[:ignore_rt]}")
  end

  def customer_tweets(handle)
    customer_tweets = fetch_tweets("@#{handle} #{TWITTER_RULE_OPERATOR[:ignore_rt]} -filter:links -from:#{handle}")
    customer_tweets.map!{|tweet| tweet unless tweet["user"]["description"].downcase.include?(handle.downcase)}.compact
  end

  def replied_tweets(handle)
    brand_tweets_list = brand_tweets(handle)
    brand_tweets_list.map{|tweet| tweet unless tweet["in_reply_to_status_id"].nil?}.compact
  end

  def replied_customer_tweets(customer_tweet_list, handle)
    customer_tweets_ids = customer_tweet_list.map{|tweet| tweet["id"]}
    replied_tweet_list  = replied_tweets(handle)
    replied_tweet_list.map{|tweet| tweet if customer_tweets_ids.include?(tweet["in_reply_to_status_id"])}.compact
  end

  def fetch_tweets(query)
    params = "count=100&result_type=#{SEARCH_RESULT_TYPE[:recent]}"
    tweets = get_tweets(query, params)
    max_id = tweets.last["id"] unless tweets.blank?
    tweet_list = tweets
    while tweets.length > 1 and tweet_list.flatten.length <= MAX_LIVE_TWEET_COUNT
      tweets = get_tweets(query, params, "&max_id=#{max_id}")
      tweets.kind_of?(Array) ? (max_id = tweets.last["id"]) : break
      tweet_list << tweets
    end
    tweet_list.flatten
  end

  def get_tweets(query, params, max_id = "")
    query_params = URI::encode("q=#{query}&#{params}#{max_id}")
    response     = twitter_client.get("/1.1/search/tweets.json?#{query_params}")
    response = JSON.parse(response.body)
    response["statuses"]
  end
  
  def can_view_welcome_page?
    basic_previlege = privilege?(:view_admin) && can_view_social? && feature?(:social_revamp) && additional_settings?
    if basic_previlege
      redirect_to social_streams_url if handles_associated?
    else
      redirect_to helpdesk_dashboard_url
    end
  end
  
  def additional_settings?
    additional_settings = current_account.account_additional_settings
    additional_settings.attributes.keys.include?("additional_settings") && (additional_settings.additional_settings.nil? || additional_settings.additional_settings[:enable_social])
  end

  def handles_associated?
    !current_account.twitter_handles_from_cache.blank?
  end
  
  def can_view_social?
    privilege?(:manage_tickets) && feature?(:twitter)
  end
  
end
