require 'spec_helper'
describe AuthorizationsController do
	integrate_views
	setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @account = create_test_account
    @user = add_test_agent(@account)
    @new_installed_application = Factory.build(:installed_application, {:application_id => 19,
                                              :account_id => @account.id, :configs => { :inputs => {}}})
    @new_installed_application.save!
  end

  it "should create authorization for google calendar" do
		@request.env["omniauth.origin"] = "id=1&app_name=google_calendar"
		@request.env["omniauth.auth"] = OmniAuth::AuthHash.new({:credentials => {:expires => true,:expires_at => "1403449470",:refresh_token => "1/fFgVJuv3VI3GN7JUImKpMsektOmDrrW7RBchDhz8guU",
		"token" => "ya29.LgD2vk9PKA42sh8AAAC8ndo_R0_Lp7AJyFOUKJutWbJCDCkUlgel57Z2RW2saQ"}, :extra =>{:raw_info => { :email => "sathish@freshdesk.com",
		:family_name=>"Babu", :gender=>"male", :given_name=>"Sathish", :hd=>"freshdesk.com", :id=>"102416485588144939702",
		:link=>"https://plus.google.com/102416485588144939702", :locale=>"en", :name=>"Sathish Babu", 
		:picture=>"https://lh3.googleusercontent.com/-gmWGnkpBsXU/AAAAAAAAAAI/AAAAAAAAACE/l4RmjyYB_z4/photo.jpg", 
		:verified_email=>true}},:info => {:email=>"sathish@freshdesk.com", :first_name=>"Sathish", 
		:image=>"https://lh3.googleusercontent.com/-gmWGnkpBsXU/AAAAAAAAAAI/AAAAAAAAACE/l4RmjyYB_z4/photo.jpg", 
		:last_name=>"Babu", :name=>"Sathish Babu"},'provider'=>"google_oauth2",:uid=>"102416485588144939702"})	
		get :create, {:code=>"4/AjFGM3kabI0u9GpZlIrA2MLyjNWr.AsBTJLpfhu8cdJfo-QBMszueosWGjQI", :controller=>"authorizations", :action=>"create", :provider=>"google_oauth2"}
		response.location.should eql "#{portal_url}/integrations/user_credentials/oauth_install/google_calendar"
	end

	it "should create authorization for google contacts" do 
		@request.env["omniauth.origin"] = "install"
		@request.env["omniauth.auth"] = OmniAuth::AuthHash.new({:credentials => { :secret => "cXGmgJ7I84ZDO3g_KSrk5-lK", :token => "1/0LRsZZCmOCyfDclmZjg9g8-eEPcBqs9a_2O_3nhn_Kk"},
				:info=>{:email=>"sathish@freshdesk.com",:name=>"Sathish Babu",:uid=>"sathish@freshdesk.com"},:provider=>"google", :uid=>"sathish@freshdesk.com"})
		get :create, {:origin=>"install", :oauth_token=>"4/2ReVhjihDDsvQxQuSBcodIAEkiPn", :oauth_verifier=>"ElX_cOA8LINHqbs8eQNuuF44",:controller=>"authorizations", :action=>"create", :provider=>"google"}
		response.should render_template "integrations/google_accounts/edit"
	end

	it "should create authorization for mailchimp" do 
		@request.env["omniauth.origin"] = "id=1"
		@request.env["omniauth.auth"] = OmniAuth::AuthHash.new({:credentials => {:expires => true, :expires_at => "1403618073",
			:token => "2a5fd25174113b11cfbcefd2b9e4e909"}, :extra => {:metadata => {:accountname=>"sathishfreshdesk",
				:api_endpoint=>"https://us8.api.mailchimp.com",:login_url=>"https://login.mailchimp.com",:role=>"owner",
				:dc=>"us8"}},:provider=>"mailchimp",:uid=>"996f8bc50b4c6c88009934d6a"})
		get :create, {:code=>"5e1f89f7246defb1586b31d12ddbadd5", :controller=>"authorizations", :action=>"create", :provider=>"mailchimp"}
		response.location.should eql "#{portal_url}/integrations/applications/oauth_install/mailchimp"
	end

	it "should create authorization for twitter" do
		@request.env["omniauth.origin"] = "http://localhost.freshpo.com/support/login"
		@request.env["omniauth.auth"] = OmniAuth::AuthHash.new({:credentials => {:secret => "zA0MiSwZRpOM5PaTiEfvITEDvDGwwkJoAmocmhPJTVKOE",
		:token => "320555803-qbVOzx8HMH10WwSnlSYZcRMrOQDYTfS4SBkHDkLh"},:info => { :description=>"", 
		:image=>"http://pbs.twimg.com/profile_images/378800000534384645/68d34547a728dfcc5236021e5beb7e84_normal.jpeg", :location=>"",
		:name=>"sathish babu.R", :nickname=>"satbuceg"},:provider=>"twitter",:uid=>"320555803"})
		get :create, {:oauth_token=>"N1n8Qwfv33QPReAFSLds2Rtcgd1hFDz87bTQebA", :oauth_verifier=>"xnalvyPIgjAd8xx2YsjanwR3sxzNA8tSD0PI0Tgs",
		 :controller=>"authorizations", :action=>"create", :provider=>"twitter"}
		 response.location.should eql "http://localhost.freshpo.com/"
	end

	it "should create authorization for facebook" do
		@request.env["omniauth.origin"] = "id=1&portal_id=1"
		@request.env["omniauth.auth"] = OmniAuth::AuthHash.new({:credentials => { :expires => true,
			:expires_at => "1408863724", 
			:token=>"CAAEAZCZBjCXkwBAHsAqBky6OhZC8p1Pnq9yTeOQsOZCveDcJtgnjv2WDNoXmmtTZAguKzk3Us9X44h3OIEW2m8E9byF5myPe7HbfyxTp4c3aLv9Y7wd7uVbzywOWrJjyrp0zXgCn760Usf35IZAqh9twYAMMFqESZA9sZAOb0i5EwJfUwZAubR20w6xomemDZCl2EZD"},
			:info => {:email=>"satbruceitan@gmail.com", :first_name=>"Sathish", :image=>"http://graph.facebook.com/100001393908238/picture?type=square",
			:last_name=>"Babu", :location=>"Chennai, Tamil Nadu", :name=>"Sathish Babu", :nickname=>"satbruceitan",
			:urls=>{:Facebook=>"https://www.facebook.com/satbruceitan"}},:provider=>"facebook",:uid=>"100001393908238"})
		curr_time = ((DateTime.now.to_f * 1000).to_i).to_s
		random_hash = Digest::MD5.hexdigest(curr_time)
		get :create, {:code=>"AQDjdI9SsCgBO0lVW2rFkd2-9XS1tGSHOowIkWcX4B1d4gTKziwBJTjeLbSUwGTuVqbEUXWPL3mrOcaMkZexUO2PRPwJF1M5RprgrtdFjV_tL9RL5hzFgjpASsB2s3NVZFdE_n65jXA_webfRQ8GTv-08YBaajbNqGKDyCc7j9Jnupi_O9ADDUis6boEdBkYlc4XAgvXGCDbtzomAiSOu1C0IY8Gt_z0vu2CWLl93sPYMyk2c_Fq0dU1y0I1hWi_xb0GzRDeEFRx9rbCU43-VEwVTkwWfjPqBvTYOdochDnQqOn_A8UtnRhlFYMpE2ExlkU",
		 :controller=>"authorizations", :action=>"create", :provider=>"facebook"}
		 response.should redirect_to "#{portal_url}/sso/login?provider=facebook&uid=100001393908238&s=#{random_hash}"
	end

	it "should fail for mailchimp" do 
		@request.env["omniauth.origin"] = "id=1"
		@request.env["omniauth.auth"] = OmniAuth::AuthHash.new()
		get :create, {:code=>"5e1f89f7246defb1586b31d12ddbadd5", :controller=>"authorizations", :action=>"create", :provider=>"mailchimp"}
		response.should redirect_to "#{portal_url}/integrations/applications"
	end
end