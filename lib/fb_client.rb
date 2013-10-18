class FBClient
  
  require 'koala'  
   
   DEFAULT_PAGE_IMG_URL = "http://profile.ak.fbcdn.net/static-ak/rsrc.php/v1/yG/r/2lIfT16jRCO.jpg"

  def initialize(fb_page, options = {} )
    @callback_url = URI.encode("#{options[:callback_url]}")
    @oauth = Koala::Facebook::OAuth.new(FacebookConfig::APP_ID, FacebookConfig::SECRET_KEY, @callback_url)
    @oauth_page_tab = Koala::Facebook::OAuth.new(FacebookConfig::PAGE_TAB_APP_ID, FacebookConfig::PAGE_TAB_SECRET_KEY, @callback_url)
    @fb_page = fb_page
  end
  
  def authorize_url(state, app = "realtime", callback_url = nil)
    callback_url = callback_url ? URI.encode(callback_url) : @callback_url 
    app_id = (app == "realtime")? FacebookConfig::APP_ID : FacebookConfig::PAGE_TAB_APP_ID
    permissions = "manage_pages,offline_access,email,read_stream,publish_stream,manage_notifications,read_mailbox,read_page_mailboxes"
    url = "https://www.facebook.com/dialog/oauth?client_id=#{app_id}&redirect_uri=#{callback_url}&state=#{state}&scope=#{permissions}"
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
      unless Account.current.facebook_pages.find_by_page_id(page[:id])
        page_source = FacebookPageMapping.find_by_facebook_page_id(page[:id])
        if page_source
          source_account = page_source.shard.domains.main_portal.first
          if source_account
            source_string = "#{source_account.domain}"
            page_id = nil
          end
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

  def auth_page_tab(code)
    oauth_access_token = @oauth_page_tab.get_access_token(code)
    @graph = Koala::Facebook::GraphAPI.new(oauth_access_token)
    profile = @graph.get_object("me")     
    profile_id=profile["id"]
    pages = @graph.get_connections(profile_id, "accounts")
    pages = pages.collect{|p| p  unless p["category"].eql?("Application")}.compact
    fb_pages = Array.new
    pages.each do |page|
      page.symbolize_keys!
      if Account.current
        page_tab = Account.current.facebook_pages.find_by_page_id(page[:id])
        if page_tab
          #This needs to be cleaned up once the migration is done
          if page_tab.page_token_tab && page_tab.page_token_tab.empty?
            fb_tab = FBPageTab.new(page_tab)
            tab = fb_tab.get(FacebookConfig::APP_ID)
            name = tab["name"] unless tab.blank? 
            fb_tab.remove(FacebookConfig::APP_ID)
          end
          page_tab.update_attribute(:page_token_tab,page[:access_token])
          if name
            fb_tab.add
            fb_tab.update(name)
          end
        end
      end
    end
  end


  def get_page
    @graph = Koala::Facebook::GraphAPI.new(@fb_page.page_token)
  end
  
  def get_profile
    @graph = Koala::Facebook::GraphAPI.new(@fb_page.access_token)
  end

  def profile_name(profile_id)
    begin
      Koala::Facebook::GraphAPI.new.get_object(profile_id).symbolize_keys[:name]
    rescue Exception => e
      return ""
    end
  end
  
  def subscribe_for_page
    begin
      realtime_subscription = get_page.put_object(@fb_page.page_id,"tabs",:app_id => FacebookConfig::APP_ID)
      @fb_page.update_attribute(:realtime_subscription,true) if(realtime_subscription)   
      puts "#{@fb_page.page_id} has been enabled for realtime subscription"
    rescue Exception => e
      @fb_page.update_attribute(:realtime_subscription,false)
      NewRelic::Agent.notice_error(e,{:description => "Error while subscribing for #{@fb_page.page_id} this is due to Access token expiry"})
    end
  end

  def subscribe(call_back_url)
    verify_token = "freshdesktoken"
    @updates = Koala::Facebook::RealtimeUpdates.new(:app_id => FacebookConfig::APP_ID, :secret => FacebookConfig::SECRET_KEY)
    @updates.subscribe("user", "feed", call_back_url, verify_token) 
  end
end