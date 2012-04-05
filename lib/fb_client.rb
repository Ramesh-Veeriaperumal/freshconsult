class FBClient
  
  require 'koala'  
   
  def initialize(fb_page  , options = {} )
    #@product = options[:product] || fb_user.product
    #@account = options[:current_account]  || fb_user.product.account
    @config = File.join(Rails.root, 'config', 'facebook.yml')
    @tokens = (YAML::load_file @config)[Rails.env]
    #@callback_url = @tokens['callback_url']
    @callback_url = "#{options[:callback_url]}"

    RAILS_DEFAULT_LOGGER.debug "app id::#{@tokens['app_id']} and secret: #{@tokens['secret_key']} and call_back_url: #{@callback_url}"
    @oauth = Koala::Facebook::OAuth.new(@tokens['app_id'], @tokens['secret_key'], @callback_url)
    @fb_page = fb_page
  end
  
  def authorize_url
    @oauth.url_for_oauth_code(:permissions => ["manage_pages","offline_access","read_stream","publish_stream","manage_notifications"])
  end
  
  def auth(code)
    oauth_access_token = @oauth.get_access_token(code)
    @graph = Koala::Facebook::GraphAPI.new(oauth_access_token)
    profile = @graph.get_object("me")     
    profile_id=profile["id"]
    pages = @graph.get_connections(profile_id, "accounts")
    pages = pages.collect{|p| p  unless p["category"].eql?("Application")}.compact
    fb_pages = Array.new
    pages.each do |page|
      page.symbolize_keys!
      page_id = page[:id]
      page_info = @graph.get_object(page_id)
      page_info.symbolize_keys!
      fb_pages << {:profile_id => profile_id , :access_token =>oauth_access_token, :page_id=> page_id,:page_name => page_info[:name], 
                   :page_token => page[:access_token],:page_img_url => page_info[:picture], :page_link => page_info[:link] , :fetch_since => 0} unless page[:access_token].blank?
    
    end
    fb_pages
  end
  
  def get_page
    @graph = Koala::Facebook::GraphAPI.new(@fb_page.page_token)
  end
  
  def get_profile
    @graph = Koala::Facebook::GraphAPI.new(@fb_page.access_token)
  end
  
  def subscribe(call_back_url)
    verify_token = "freshdesktoken"
    @updates = Koala::Facebook::RealtimeUpdates.new(:app_id => @tokens['app_id'], :secret => @tokens['secret_key'])
    @updates.subscribe("user", "feed", call_back_url, verify_token) 
  end
  
  
  
  
  
end