require 'spec_helper'

describe Mobile::NotificationsController do
    self.use_transactional_fixtures = false

    before(:each) do
	    @request.user_agent = "Freshdesk_Native_Android"
	    @request.accept = "application/json"
	    @request.env['HTTP_AUTHORIZATION'] = "Basic #{Base64.encode64("#{@agent.single_access_token}:X").delete("\r\n")}"
	    @request.format = "json"
  	end

  	it "should register push notification" do
  		attributes = {
	  		"registration_key" => "12345",
  			"device_os" => "Android",
  			"platform" => "android",
  			"clean_up" => 1,
        "format" => 'json',
  			"notification_types" => {
  				"NEW_RESPONSE_NOTIFICATION" => 1,
  				"STATUS_UPDATE_NOTIFICATION" => 1,
  				"TICKET_ASSIGNED_NOTIFICATION" => 1,
  				"GROUP_ASSIGNED_NOTIFICATION" => 1,
  				"NEW_TICKET_NOTIFICATION" => 1
  				}
  			}
		  post :register_mobile_notification, attributes
  		json_response["success"].should be_true
  	end
end