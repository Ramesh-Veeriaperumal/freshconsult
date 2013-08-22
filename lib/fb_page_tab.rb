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
    return_value = fb_sandbox({}) {
      facebook_data = oauth.parse_signed_request(signed_request)
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
                            { :access_token => self.fb_page.page_token,
                              :app_id => FacebookConfig::APP_ID
                            })
    }
    return_value
  end

  def get
    return_value = fb_sandbox([]) {
      graph.get_connections("me", "tabs/#{FacebookConfig::APP_ID}", 
                            { :access_token => self.fb_page.page_token}).first
    }
    return_value
  end

  def update name
    return_value = fb_sandbox(false) {
      graph.put_connections("me", "tabs/app_#{FacebookConfig::APP_ID}", 
                            { :access_token => self.fb_page.page_token, 
                              :custom_name => name
                            })
    }
    return_value
  end

  def remove
    return_value = fb_sandbox(false) {
      graph.delete_connections("me", "tabs/app_#{FacebookConfig::APP_ID}", 
                                { :access_token => self.fb_page.page_token})
    }
    return_value
  end

  protected

    def fb_sandbox(return_value = nil)
      begin
        return_value = yield
      rescue Koala::Facebook::APIError => e
        if e.fb_error_type == 4 #error code 4 is for api limit reached
          fb_page.attributes = {:last_error => e.to_s}
          fb_page.save
          Rails.logger.debug "API Limit reached - #{e.to_s}"
          new_relic_error_notice(e)
        else
          attributes_on_error(e)
          fb_page.save
          Rails.logger.debug "APIError while processing facebook - #{e.to_s}"
          new_relic_error_notice(e)
        end
      rescue Exception => e
        Rails.logger.debug "Error while processing facebook - #{e.to_s}"
        NewRelic::Agent.notice_error(e)
      end
      return return_value
    end

    def any_error e
      Social::FacebookWorker::ERROR_MESSAGES.any? {|k,v| e.include?(v)}
    end

    def token_or_permission_error e
      e.include?(Social::FacebookWorker::ERROR_MESSAGES[:access_token_error]) ||
        e.include?(Social::FacebookWorker::ERROR_MESSAGES[:permission_error])
    end

    def attributes_on_error e
      fb_page.attributes = {:reauth_required => true, :last_error => e.to_s} if any_error(e.to_s)
      fb_page.attributes = {:enable_page => false} if token_or_permission_error(e.to_s)
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