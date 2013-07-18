class FBPageTab

  require 'koala'

  attr_accessor :fb_page

  def initialize page = nil
    self.fb_page = page
  end

  def graph
    @graph ||= Koala::Facebook::GraphAPI.new(self.fb_page.page_token) if fb_page
  end

  def oauth
    @oauth ||= Koala::Facebook::OAuth.new(FacebookConfig::APP_ID, FacebookConfig::SECRET_KEY)
  end

  def read_facebook signed_request
    facebook_data = oauth.parse_signed_request(signed_request)
    page = facebook_data["page"]["id"] if facebook_data["page"]
    { :page_id => facebook_data["page"]["id"], :oauth_token => facebook_data["oauth_token"] }
  end

  def add
    graph.put_connections("me", "tabs", 
                          { :access_token => self.fb_page.page_token,
                            :app_id => FacebookConfig::APP_ID})
  end

  def get
    graph.get_connections("me", "tabs/#{FacebookConfig::APP_ID}", 
                          { :access_token => self.fb_page.page_token})
  end

  def update name
    begin
      graph.put_connections("me", "tabs/app_#{FacebookConfig::APP_ID}", 
                          { :access_token => self.fb_page.page_token, 
                            :custom_name => name} )
    rescue
      return false
    end
  end

  def remove
    graph.delete_connections("me", "tabs/app_#{FacebookConfig::APP_ID}", 
                              { :access_token => self.fb_page.page_token})
  end
end