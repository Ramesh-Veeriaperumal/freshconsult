class Integrations::GoogleCalendarEmailFinder

  def find_and_store_user_registered_email(inst_app_user_credentail)
  	
    domain = 'www.googleapis.com'
  	access_token = inst_app_user_credentail.auth_info['oauth_token']

  	hrp = HttpRequestProxy.new
  	params = { :domain => domain, :ssl_enabled => 'true', :rest_url => "oauth2/v2/userinfo"}
  	request_params = { :method => "get", :user_agent => "Freshdesk", :auth_header => "OAuth #{inst_app_user_credentail.auth_info['oauth_token']}"  }
  	response = hrp.fetch_using_req_params(params, request_params)

    Rails.logger.debug "Gcal response: #{response.inspect}\n"    
    res_hash = ActiveSupport::JSON.decode response[:text]

    Rails.logger.debug "Result Hash: #{res_hash.inspect}"
    inst_app_user_credentail.auth_info['email'] = res_hash['email']

  end

end
