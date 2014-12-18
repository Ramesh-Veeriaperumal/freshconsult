require 'spec_helper'
describe Integrations::UserCredentialsController do
	integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

	before(:all) do
		#@account = create_test_account
  	@user = add_test_agent(@account)
  	@app_name = 'google_calendar'
  	create_installed_applications({ :configs => { :inputs => {} }, :account_id => @account.id, :application_name => @app_name})
  	app_config = {:app_name => @app_name,:refresh_token=>"1/Ku3-Hs6W2HouY5W-JoVCb-J8vnVjt9T4WAnDnsOcgkU",:oauth_token=>"ya29.NQB6qlHo1445mhoAAAApCNDUdpEMgcyiA_Fn8LyeaCbvAzNlMGAiiK6aE03fyQ"}
  end

  before(:each) do
    log_in(@user)
  end

	it "should oauth install" do 
    config_params = "{\"app_name\":\"google_calendar\",\"refresh_token\":\"1/Ku3-Hs6W2HouY5W-JoVCb-J8vnVjt9T4WAnDnsOcgkU\",\"oauth_token\":\"ya29.NQB6qlHo1445mhoAAAApCNDUdpEMgcyiA_Fn8LyeaCbvAzNlMGAiiK6aE03fyQ\"}"
    key_options = { :account_id => @account.id, :provider => 'google_calendar'}
    key_spec = Redis::KeySpec.new(Redis::RedisKeys::APPS_AUTH_REDIRECT_OAUTH, key_options)
    kv_store = Redis::KeyValueStore.new(key_spec, config_params, {:group => :integration}).set_key
		post :oauth_install, {'id' => "google_calendar"}
    response.should redirect_to "http://localhost.freshpo.com/integrations/applications"
	end

	it "should create user credentials" do
		post :create, {"app_name" => "google_calendar", "username" => "freshdesk", "password" => "freshdesk"}
    response.status.should eql "201 Created"
	end
end