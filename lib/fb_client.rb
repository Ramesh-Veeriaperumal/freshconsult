class FBClient
  
  require 'koala'  
   
   DEFAULT_PAGE_IMG_URL = "http://profile.ak.fbcdn.net/static-ak/rsrc.php/v1/yG/r/2lIfT16jRCO.jpg"

  def initialize(fb_page  , options = {} )

    @callback_url = URI.encode("#{options[:callback_url]}")
    @oauth = Koala::Facebook::OAuth.new(FacebookConfig::APP_ID, FacebookConfig::SECRET_KEY, @callback_url)
    @fb_page = fb_page
  end
  
  def authorize_url(state)
    permissions = "manage_pages,offline_access,read_stream,publish_stream,manage_notifications,read_mailbox,read_page_mailboxes"
    url = "https://www.facebook.com/dialog/oauth?client_id=#{FacebookConfig::APP_ID}&redirect_uri=#{@callback_url}&state=#{state}&scope=#{permissions}"
    return url
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
      page_source = FacebookPageMapping.find_by_facebook_page_id(page[:id])
      if page_source
        source_account = page_source.shard.domains.main_portal.first
        if source_account
          source_string = "#{source_account.domain}"
          page_id = nil
        end
      end
      page_info = @graph.get_object(page[:id])  
      page_picture = @graph.get_picture(page[:id],{:type => "small"})
      page_info.symbolize_keys!
      fb_pages << {:profile_id => profile_id , :access_token =>oauth_access_token, :page_id=> page_id,:page_name => page_info[:name], 
                   :page_token => page[:access_token],:page_img_url => page_picture || DEFAULT_PAGE_IMG_URL, :page_link => page_info[:link] , :fetch_since => 0,
                   :reauth_required => false , :source => source_string, :last_error => nil} unless page[:access_token].blank?
    
    end
    fb_pages
  end
  
  def subscribe(call_back_url)
    verify_token = "freshdesktoken"
    @updates = Koala::Facebook::RealtimeUpdates.new(:app_id => FacebookConfig::APP_ID, :secret => FacebookConfig::SECRET_KEY)
    @updates.subscribe("user", "feed", call_back_url, verify_token) 
  end
end