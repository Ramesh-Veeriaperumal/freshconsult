class Social::WelcomeController < ApplicationController
  
  include Social::Twitter::Constants
  
  before_filter { |c| c.requires_feature :twitter }
  skip_before_filter :check_account_state
  before_filter :check_account_state
  before_filter :can_view_welcome_page?, :only => [:index]
  
  def index
    @selected_tab = :social
    @twitter_enable = social_enabled?
  end

  def get_stats
    handle = params[:twitter_handle].gsub(/^@/,'')
    
    begin
      brand_tweets, customer_tweets = get_all_tweets(handle)
      replied_customer_tweets = filter_brand_replies(brand_tweets, customer_tweets, handle)    
      
      customer_tweets_length  = customer_tweets.length
      replied_tweets_length   = replied_customer_tweets.length
      @perct = (customer_tweets_length == 0) ? 0 : (replied_tweets_length * 100)/customer_tweets_length
    rescue Exception => e
      @get_stats_error = "#{I18n.t('social.streams.twitter.client_error')}"
    end
    
    respond_to do |format|
      format.js
    end
  end

  def enable_feature
    feature = params[:twitter] == "true" ? true : false
    account_additional_settings = current_account.account_additional_settings
    if account_additional_settings.additional_settings.present?
      account_additional_settings.additional_settings[:enable_social] = feature
      account_additional_settings.save
    else
      additional_settings = {
        :enable_social => feature
      }
      account_additional_settings.update_attributes(:additional_settings => additional_settings)
    end
    redirect_to admin_home_index_url
  end

  private
  def get_all_tweets(handle)
    all_tweets = fetch_tweets("@#{handle} OR #{TWITTER_RULE_OPERATOR[:from]}#{handle} #{TWITTER_RULE_OPERATOR[:ignore_rt]}")
    customer_tweets, brand_tweets = [], []
    all_tweets.each do |tweet|
      if tweet["user"]["screen_name"].downcase == handle.downcase
        brand_tweets << tweet unless tweet["in_reply_to_status_id"].nil?
      else
        customer_tweets << tweet if valid_customer_tweet?(tweet, handle)
      end
    end
    [brand_tweets, customer_tweets]
  end

  def fetch_tweets(query)
    params = "count=100&result_type=#{SEARCH_RESULT_TYPE[:recent]}"
    tweet_list = []
    max_id = ""
    
    #API call limited to 500 tweets (5 times)
    5.times do 
      tweets = get_tweets(query, params, max_id)
      break if tweets.blank? or tweets.length <= 1
      max_id = "&max_id=#{tweets.last["id"]}"
      tweet_list <<  (tweet_list.empty? ? tweets : tweets[1..tweets.length]) #index 0 is a duplicate tweet
    end
    
    tweet_list.flatten
  end

  def get_tweets(query, params, max_id = "")
    query_params = URI::encode("q=#{query}&#{params}#{max_id}")
    response     = twitter_client.get("/1.1/search/tweets.json?#{query_params}")
    response     = JSON.parse(response.body)
    response["statuses"]
  end
  
  def valid_customer_tweet?(tweet, handle)
    !tweet["user"]["description"].downcase.include?(handle.downcase) and !tweet["text"].include?("http://")
  end    
  
  def filter_brand_replies(brand_tweets, customer_tweets, handle)
    customer_tweets_ids = customer_tweets.map{|tweet| tweet["id"]}
    brand_tweets.map{|tweet| tweet if customer_tweets_ids.include?(tweet["in_reply_to_status_id"])}.compact
  end  
  
  def can_view_welcome_page?
    basic_previlege = privilege?(:view_admin) && can_view_social? && social_enabled?
    if basic_previlege
      redirect_to social_streams_url if handles_associated?
    else
      redirect_to helpdesk_dashboard_url
    end
  end
  
  def can_view_social?
    feature?(:twitter) && privilege?(:manage_tickets)
  end  
  
  def social_enabled?
    settings = current_account.account_additional_settings.additional_settings
    settings.blank? || settings[:enable_social].nil? || settings[:enable_social]
  end

  def handles_associated?
    !current_account.twitter_handles_from_cache.blank?
  end
  
  def twitter_client
    client = OAuth2::Client.new(TwitterConfig::CLIENT_ID, TwitterConfig::CLIENT_SECRET, :site => 'https://api.twitter.com', :authorize_url => '/oauth2/authorize', :token_url=>"/oauth2/token")
    params = {'grant_type' => 'client_credentials', "client_id" => TwitterConfig::CLIENT_ID, "client_secret" => TwitterConfig::CLIENT_SECRET}
    opts   = {'refresh_token' => nil}
    client.get_token(params, opts)
  end  
  
end
