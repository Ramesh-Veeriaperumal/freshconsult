require 'spec_helper'

describe Mobile::NotificationsController do
    self.use_transactional_fixtures = false

    before(:each) do
	    api_login
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
      Mobile::NotificationsController.any_instance.stubs(:publish_to_channel).returns(1)
		  post :register_mobile_notification, attributes
  		json_response["success"].should be true
  	end
end