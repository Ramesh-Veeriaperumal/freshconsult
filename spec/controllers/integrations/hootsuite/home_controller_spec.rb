require 'spec_helper'

describe Integrations::Hootsuite::HomeController do
	setup :activate_authlogic
	self.use_transactional_fixtures = false
	
	before(:all) do
     @hs_params = {:pid=>"4095315", :uid=>"10788857",:ts=>"1434097760", :token=>"ba9be29c71f33fb151acd8b0b64a2891597e1077bb3c407a475f47677c6d2c92418c5fb0a30fbbd8b8dc3f3cbc1b3adbeac50c4a4f9bd6230d7a411d79ba285b"}
     Integrations::HootsuiteRemoteUser.create(
        :configs => {:pid => @hs_params[:pid]},
        :account_id => @agent.account_id,
        :remote_id => @hs_params[:uid])
	end

	before(:each) do
		log_in(@agent)
	end

	 it "should go to the index page" do
	 	ticket = @account.tickets.first
	 	ticket.responder_id = @agent.id
	 	ticket.save!
	 	post :iframe_page ,@hs_params
	 	response.should redirect_to(:controller => "home",:action => "index")
	 end

	 it "should redirect to login page if user logout" do
	 	UserSession.find.destroy
	 	get :index ,@hs_params
	 	response.should redirect_to(@hs_params.merge(:controller => "home",:action => "hootsuite_login"))
	 end

	 it "render error page if hootsuite params are missing" do
	 	post :iframe_page
	 	response.body.should eql "Error: It appears that you are not loading this page from inside a HootSuite stream"
	 end

	 it "should redirect to login page if a new user" do
	 	custom_param = @hs_params.merge(:uid => "1234",:token => "c5d2cf8e454e8e1cc47ceee68fdd2f33fa79bb42c36a99cece97355680a3c3bc04925e60195beb8e38ab6e18e97b2183c114d4a07770b53f22fb85aa1d42c035")
	 	post :iframe_page ,custom_param
	 	response.should redirect_to(:controller => "home",:action => "domain_page")
	 end

	it "search by keyword" do
		post :search ,@hs_params.merge(:search_type => "keyword",:search_text => "sample")
		response.should render_template "integrations/hootsuite/home/index"
	end

	it "search by display_id" do
		post :search ,@hs_params.merge(:search_type => "ticket",:search_text => "1")
		response.should render_template "integrations/hootsuite/home/index"
	end

	it "filter based on priority and status" do
		post :search ,@hs_params.merge(:search_type => "filter",:ticket_status => 2,:ticket_priority => 1)
		response.should render_template "integrations/hootsuite/home/index"
	end

	it "should redirect to index with params on filter" do
		custom_param = @hs_params.merge(:search_type => "ticket",:search_text => "1")
		post :search ,custom_param
		response.should render_template "integrations/hootsuite/home/index"
	end

	it "should redirect to index with params on serch" do
		custom_param = @hs_params.merge(:search_type => "filter",:ticket_status => 2,:ticket_priority => 1)
		post :search ,custom_param
		response.should render_template "integrations/hootsuite/home/index"
	end

	it "should redirect to login" do
		custom_param = @hs_params.merge(:uid => "1234",:token => "c5d2cf8e454e8e1cc47ceee68fdd2f33fa79bb42c36a99cece97355680a3c3bc04925e60195beb8e38ab6e18e97b2183c114d4a07770b53f22fb85aa1d42c035")
		post :iframe_page ,custom_param
		response.should redirect_to(:controller => "home",:action => "domain_page")
	end

	it "should redirect to login on false credentials" do
		custom_param = @hs_params.merge(:uid => "1234",:token => "c5d2cf8e454e8e1cc47ceee68fdd2f33fa79bb42c36a99cece97355680a3c3bc04925e60195beb8e38ab6e18e97b2183c114d4a07770b53f22fb85aa1d42c035",:email => "gaurav@freshdesk.com",:freshdesk_domain => "test5810.freshdesk.com",:apikey => "falseapikey")
		post :verify_domain ,custom_param
		response.should redirect_to(custom_param.merge(:controller => "home",:action => "domain_page"))
	end

	it "should create an entry for remote user after login" do
		DomainMapping.create(:account_id=>@agent.account_id,:domain=>"test5810.freshdesk.com")
		custom_param = @hs_params.merge(:uid => "1234",:token => "c5d2cf8e454e8e1cc47ceee68fdd2f33fa79bb42c36a99cece97355680a3c3bc04925e60195beb8e38ab6e18e97b2183c114d4a07770b53f22fb85aa1d42c035")
		custom_param = custom_param.merge(:email => "gaurav@freshdesk.com",:freshdesk_domain => "test5810.freshdesk.com",:apikey => "eBy0QXueLvNxPnE76r1k")
		post :verify_domain ,custom_param
		response.should redirect_to(custom_param.merge(:controller => "home",:host => @account.full_domain,:action => "domain_page"))
	end

	it "should logout" do
		get :log_out ,@hs_params
		UserSession.find.should be_nil
	end

	it "go to the index page" do
	 	post :iframe_page ,@hs_params
	 	response.should redirect_to(:controller => "home")
	 end

	it "should register hs events" do
	  post :plugin ,@hs_params
 	  response.should render_template "integrations/hootsuite/home/plugin" 
	end

	it "should display ticket create form for twitter" do
	  twitter_params = {"description"=>"description", "subject"=>"subject", "twitter_id"=>"@TimesNow", "tweet_id"=>"599181487838081027"}
 	  get :handle_plugin ,@hs_params.merge(twitter_params)
  	response.should render_template "integrations/hootsuite/home/handle_plugin" 
	end

	it "should display ticket create form for facebook" do
	  facebook_params = {"description"=>"description", "subject"=>"subject", "fb_profile_id"=>"1234", "post_id"=>"599181487838081027"}
	  get :handle_plugin ,@hs_params.merge(facebook_params)
	  response.should render_template "integrations/hootsuite/home/handle_plugin"
	end

	it "should render login page if false credential" do
	 	UserSession.find.destroy
	 	UserSession.find.should be_nil
	 	post :create_login_session,@hs_params.merge(:user_session=>{:email=> @agent.email, :password=>"wrongpassword", :remember_me=>"0"})
	 	response.should render_template "integrations/hootsuite/home/hootsuite_login"
	 end

	it "should create a login session" do
		UserSession.find.destroy
		UserSession.find.should be_nil
		post :create_login_session,@hs_params.merge(:user_session=>{:email=> @agent.email, :password=>"test", :remember_me=>"0"})
		UserSession.find.should be_present
	 end

	it "should clear cookies" do
		HTTParty.stubs(:delete).returns(true)
		delete :destroy ,@hs_params
		UserSession.find.should be_nil
	end

	it "should delete hs_user on logout" do
		delete :delete_hootsuite_user ,@hs_params
		response.body.should include("success")
	end

	it "should delete hs_user on uninstall" do
		Integrations::HootsuiteRemoteUser.create(:remote_id => "123",:account_id => 1)
		delete :uninstall ,{:i => "123"}
		Integrations::HootsuiteRemoteUser.where("remote_id = ?","123").first.should be_nil
	end
end