require 'spec_helper'

describe AccountsController do
	it 'should signup a new account' do
		admin_email = Faker::Internet.email
		admin_name = Faker::Name.name
		session_json_string = '{"browser":{},"device":{"is_tablet":"false","is_mobile":"true","is_phone":"false"},"time":{},
                            "location":{"city_name":"Chennai","countryName":"India","ipAdderss":"192.168.2.6","zipCode":"600078",
                            "regionName":"Chennai","countryCode":"IN","timeZone":"+05:30","longitude":"80.2442769","latitude":"12.9698946"},
                            "current_session":{"search":""},"locale":{"lang":"English"}}'
    session_json = JSON.parse(session_json_string)
		signup_params = { "callback"=>"", "account"=>{"name"=>"RSpec Test", "domain"=>"rspectest2"}, 
      								"utc_offset"=>"5.5", "user"=>{"email"=>admin_email, "name"=>admin_name}, "session_json" => session_json }
    

		Resque.inline = true
		Billing::Subscription.any_instance.stubs(:create_subscription).returns(true)
		@request.host = @account.full_domain
		@request.user_agent = "Freshdesk_Native_Android"
		@request.accept = "application/json"
		@request.env['format'] = 'json'
		@request.format = "json"
		post :new_signup_free, signup_params
		Resque.inline = false
		Billing::Subscription.any_instance.unstub(:create_subscription)
		json_response.should include("success", "host", "t", "support_email")
		json_response["success"].should eql(true)
		new_user = User.find_by_email(json_response["support_email"])
		json_response["t"].should be_eql(new_user.single_access_token)
	end
end
