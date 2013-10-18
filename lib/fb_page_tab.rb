class FBPageTab

  require 'koala'

  attr_accessor :fb_page, :app_id

  def initialize page = nil, app_id = nil
    self.fb_page = page
    self.app_id = app_id
  end

  def graph
    if fb_page
      page_token = fb_page.page_token
      #Condition for Handling newly registered users for facebook tab
      #Condition for Handling converted users from old to new facebook tab app
      #remove this code after migration
      page_token = fb_page.page_token_tab if fb_page.page_token_tab && !fb_page.page_token_tab.empty?
      @graph ||= Koala::Facebook::GraphAPI.new(page_token)
    end
  end

  def oauth
    #if app_id is present then it means the request is coming from new app
    #remove this code after migration
    unless app_id
      @oauth ||= Koala::Facebook::OAuth.new(FacebookConfig::APP_ID, FacebookConfig::SECRET_KEY)
    else
      @oauth ||= Koala::Facebook::OAuth.new(FacebookConfig::PAGE_TAB_APP_ID,FacebookConfig::PAGE_TAB_SECRET_KEY)
    end
  end

  def has_permissions? token
    fb_user = Koala::Facebook::GraphAPI.new(token)
    permissions = fb_user.get_connections('me','permissions').first
    (FacebookConfig::USER_PERMISSIONS - permissions.keys).empty?
  end

  def read_facebook signed_request
    return_value = fb_sandbox({}) {
      facebook_data = oauth.parse_signed_request(signed_request)
      facebook_data["oauth_token"] = nil unless facebook_data["oauth_token"] and has_permissions?(facebook_data["oauth_token"])
      page = facebook_data["page"]["id"] if facebook_data["page"]
      { 
        :page_id => facebook_data["page"]["id"], 
        :oauth_token => facebook_data["oauth_token"] 
      }
    }
    return_value
  end

  def add
    return_value = fb_sandbox(false) {
      graph.put_connections("me", "tabs", 
                            { :access_token => self.fb_page.page_token_tab,
                              :app_id => FacebookConfig::PAGE_TAB_APP_ID
                            })
    }
    return_value
  end

  def get(fb_app_id = nil)
    page_token = self.fb_page.page_token
    unless fb_app_id
      fb_app_id = FacebookConfig::PAGE_TAB_APP_ID
      page_token = self.fb_page.page_token_tab
    end
    return_value = fb_sandbox() {
      page_tab_name = graph.get_connections("me", "tabs/#{fb_app_id}", 
                            { :access_token => page_token})
      page_tab_name.blank? ? [] : page_tab_name.first 
    }
    return_value
  end

  def update name
    return_value = fb_sandbox(false) {
      graph.put_connections("me", "tabs/app_#{FacebookConfig::PAGE_TAB_APP_ID}", 
                            { :access_token => self.fb_page.page_token_tab, 
                              :custom_name => name
                            })
    }
    return_value
  end

  def remove(fb_app_id = nil)
    page_token = self.fb_page.page_token
    unless fb_app_id
      fb_app_id = FacebookConfig::PAGE_TAB_APP_ID
      page_token = self.fb_page.page_token_tab
    end
    return_value = fb_sandbox(false) {
      graph.delete_connections("me", "tabs/app_#{fb_app_id}", 
                                { :access_token => page_token})
    }
    return_value
  end

  protected

    def fb_sandbox(return_value = nil)
      begin
        return_value = yield
      rescue Exception => e
        Rails.logger.debug "Error while processing facebook - #{e.to_s}"
        NewRelic::Agent.notice_error(e)
      end
      return return_value
    end

    def new_relic_error_notice e
      NewRelic::Agent.notice_error(e, {:custom_params => {
                                            :error_type => e.fb_error_type, 
                                            :error_msg => e.to_s, 
                                            :account_id => fb_page.account_id, 
                                            :id => fb_page.id 
                                            }
                                          })
    end
end