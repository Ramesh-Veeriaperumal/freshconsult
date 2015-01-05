require 'spec_helper'
describe Integrations::OauthUtilController do
	integrate_views
	setup :activate_authlogic
  self.use_transactional_fixtures = false

	before(:all) do
		#@account = create_test_account
	  @user = add_test_agent(@account)
	  app = create_user_credentials({:user_id => @user.id, :auth_info => { 'refresh_token' => "1/9zS19IiB-SkYeg6MjUE6cfIvTZIqbEEXzn3J-uw8ils", 
		     								'oauth_token' => "ya29.NAABYWd0ZOrbyxkAAAC6NPsuDQwcBaz9x1s4fyV0JbtgzNmFDfZ4O8XVJEHz2w", 
		     								:email => "satbruceitan@gmail.com"}, :account_id => @account.id,:application_name => 'google_calendar',:configs => { :inputs => {} }})

	  @new_installed_app = Factory.build(:installed_application, :application_id => 9,
                        :account_id => @account.id,
                        :configs => {:inputs=>
                        {"refresh_token"=>"5Aep8617VFpoP.M.4vr0B8cw7H4cGnnLPu4C1ZIHSC2psImKCK1bbT_IZQxg32DkO6BQJtg0UVmveObnUEK_x8D", 
                        	"oauth_token"=>"00D90000000v4Td!AQsAQDMrLfWmQpvBDzAP_2rXxgk9RQIDWm1nG.pQltZofhcIZ7Aiz9eq3jh9_I2WlGFOkEyoq2DcAOmSQGdrWhaCt.UyOoJ7", 
                        	"instance_url"=>"https://ap1.salesforce.com", "contact_fields"=>"Name", "lead_fields"=>"Name", "account_fields"=>"Name",
                        	"contact_labels"=>"Full Name", "lead_labels"=>"Full Name", "account_labels"=>"Account Name"}
                        })
	  @new_installed_app.save!
  end

  before(:each) do
	  log_in(@user)
	end


	it "should get access token for user_specific_auth" do 
		get :get_access_token, {:controller=>"integrations/oauth_util", :action=>"get_access_token",:app_name=>"google_calendar"}
		response.status.should eql "200 OK"
	end

	it "should get access token for non_user_specific_auth" do
	get :get_access_token, {:controller=>"integrations/oauth_util", :action=>"get_access_token",:app_name=>"salesforce"} 
	response.status.should eql "200 OK"
	end

	it "failure case" do
		get :get_access_token, {:controller=>"integrations/oauth_util", :action=>"get_access_token",:app_name=>"pivotal_tracker"} 
		response.status.should eql "200 OK"
	end
end