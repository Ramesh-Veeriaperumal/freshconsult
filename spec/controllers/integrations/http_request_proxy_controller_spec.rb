require 'spec_helper'
describe HttpRequestProxyController do
	integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

	before(:all) do
		#@account = create_test_account
	  @user = add_test_agent(@account)
	  test = create_application({ :name => "pivotal_tracker",
		     								:display_name => "pivotal_tracker",:listing_order => 23,
		     								:options => {
															        :keys_order => [:api_key, :pivotal_update],
															        :api_key => { :type => :text, :required => true, :label => "integrations.pivotal_tracker.api_key", :info => "integrations.pivotal_tracker.api_key_info"},
															        :pivotal_update => { :type => :checkbox, :label => "integrations.pivotal_tracker.pivotal_updates"}
																	    },:account_id => @account.id,
		     								:application_type => "pivotal_tracker"})
	  @new_installed_application = Factory.build(:installed_application, {:application_id => test.id,
	                                              :account_id => @account.id, :configs => { :inputs => {'api_key' => "c599b57edad0cb430d6fbf2543450c6c", 'pivotal_update' => '1'}}})
		@new_installed_application.save!

		shopify_add = create_application({:name => "shopify",
	        :display_name => "integrations.shopify.label",
	        :description => "integrations.shopify.desc",
	        :listing_order => 24,
	         :options => {:direct_install => false, :keys_order => [:shop_name],
	                     :shop_name => { :type => :text, :required => true, :label => "integrations.shopify.form.shop_name", :info => "integrations.shopify.form.shop_name_info", :rel => "ghostwriter", :autofill_text => ".myshopify.com"},
	        },
	        :application_type => "shopify",
	        :account_id => 0
	        })

		@shopify = Factory.build(:installed_application, {:application_id => shopify_add.id,:account_id => @account.id,
			:configs=>{:inputs=>{"refresh_token"=>"", "oauth_token"=>"fbc1ea7dd7bef91e31078f079c08dbef", "shop_name"=>"freshdesk-3.myshopify.com"}}})
		@shopify.save!

		@icontact = Factory.build(:installed_application, {:application_id => 15, :account_id => @account.id,
			:configs => {:inputs=>{"api_url"=>"https://app.icontact.com/icp/a/1395155/c/4621/", "username"=>"krishjarvis123@gmail.com", 
			"password"=>"u4jUVGvVlS312ahyhnH/b52TfDsSsYzy9lPJauQh/c8IdH16TfER9Gs7HCYBex9yjLI4WNkzu9inRI4rRk6BFgJya8Ljh2tJSQ0Tkb64MuNS4UCWy/Wmkv1/m/9pNN3RVLq/GWhoVaJDkflRghfXsa7m5BFapTWbY+wXsIxQgALBXynED7rGtbhNYlw05pYDotp08kPApnV7pZtfMWES2UUBV+1+0te3wm6sePjjzEC7FcHHuYLaQ7h81u+DxpsmsMbdZc9u9vLNcVe7VO/3UoT/WyQGpc6sgWYxjgSScufMD+Q1XeFX5wx8Cy1CObaNY8d6Cmor4F7mhwrpaW3OXw=="}}
			})
		@icontact.save!

		@survey_monkey = Factory.build(:installed_application, {:application_id => 21, :account_id => @account.id,
			:configs => {:inputs=>{"refresh_token"=>"", "oauth_token"=>"paTBz61kMlD0mPWrsaHR3921EuYbHlBvqU0GDZQ.5nahBvB1GbdZpbh2WnOzXY4Sx3DdjRm5L63Sshs3DDbF.qtbUQgFY0b6HFlivlIWW8c=", 
				"survey_text"=>"Would be awesome to hear back.", "survey_link"=>"", "survey_id"=>"53833928", "collector_id"=>"55458745", "send_while"=>"1", 
				"groups"=>{"0"=>{"survey_id"=>"53833928", "collector_id"=>"55458745"}}}}
			})
		@survey_monkey.save!
	end

		before(:each) do
		  log_in(@user)
		end

	it "should fetch data for pivotal tracker" do 
		@request.env["REQUEST_METHOD"] = "POST"
		post :fetch, { :rest_url => "services/v5/projects/1106038/stories/73545130", :method => "get" , :content_type => "application/json", :domain => "www.pivotaltracker.com",
									:ssl_enabled => "true", :accept_type => "application/json", :app_name => "pivotal_tracker",:use_server_password => true }
		response.status.should eql "200 OK"
	end

	it "should fetch data for icontact" do
		@request.env["REQUEST_METHOD"] = "POST"
		post :fetch, { :rest_url => "contacts?email=sathish@freshdesk.com&status=total", :method => "get" , :content_type => "application/json", :domain => "https://app.icontact.com/icp/a/1395155/c/4621/",
									:ssl_enabled => "true", :accept_type => nil, :app_name => "icontact",:username=>"krishjarvis123@gmail.com",:use_server_password => true }
		response.body.should_not be_nil
	end

	it "should fetch data for harvest with user_credentials" do 
		create_user_credentials({:user_id => @user.id, :auth_info => { :username => "sathish@freshdesk.com", 
	  	     								:password => "test123"}, :account_id => @account.id,:application_name => 'harvest',:configs => {:inputs=>{"title"=>"Harvest", 
	  	     								"domain"=>"sathishharvest.harvestapp.com", "harvest_note"=>"Freshdesk Ticket # {{ticket.id}}"}}})
		post :fetch, { :rest_url=>"daily", :content_type=>"application/xml", :domain=>"sathishharvest.harvestapp.com",
									 :ssl_enabled=>"true", :accept_type=>"application/xml", :method=>"get", :username=>"sathish@freshdesk.com",
									 :use_server_password=>"true", :app_name=>"harvest", :controller=>"http_request_proxy", :action=>"fetch", 
									 :password=>"test123"}
		response.body.should_not be_nil				 
	end

	it "should fetch data for survey monkey" do
		post :fetch, {:body=>"{\"fields\": [\"title\", \"survey_id\"]}", :method=>"post", :rest_url=>"v2/surveys/get_survey_list?api_key=smonkey_secret", 
								:use_placeholders=>"true", :domain=>"api.surveymonkey.net", :ssl_enabled=>"true", :accept_type=>nil, "username"=>"", 
								:use_server_password=>"true", :app_name=>"surveymonkey", :resource=>"v2/surveys/get_survey_list", :controller=>"http_request_proxy", :action=>"fetch"}
		response.body.should_not be_nil
	end

	
	# it "should fetch data for shopify" do 
	# 	@request.env["REQUEST_METHOD"] = "POST"
	# 	post :fetch, {:rest_url=>"admin/orders/search.json?query=email:sudharshan.v@freshdesk.com&access_token=fbc1ea7dd7bef91e31078f079c08dbef", :domain=>"https://freshdesk-3.myshopify.com", :ssl_enabled=>nil, :accept_type=>nil, :method=>"get", :username=>"", :use_server_password=>"true", :app_name=>"shopify", :resource=>"admin/orders/search.json?query=email:sudharshan.v@freshdesk.com",:controller=>"http_request_proxy", :action=>"fetch"}
	# 	response.status.should eql "200 OK"
	# end
end
