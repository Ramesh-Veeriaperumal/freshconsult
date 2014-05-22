require 'spec_helper'

describe SsoController do
	integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @account = create_test_account
    @user = add_test_agent(@account)
    @authorization = Factory.build(:authorization, :provider => "facebook",
                    :uid => "12345678", :user_id => @user.id, :account_id => @account.id )
    @authorization.save(false)
    key_options = { :account_id => @account.id, :user_id => @user.id, :provider => @authorization[:provider]}
    @key_spec = Redis::KeySpec.new(Redis::RedisKeys::SSO_AUTH_REDIRECT_OAUTH, key_options)
  end

  before(:each) do
    log_in(@user)
    @request.host = @account.full_domain
  end

  it "should redirect to facebook home" do
    curr_time = ((DateTime.now.to_f * 1000).to_i).to_s
    random_hash = Digest::MD5.hexdigest(curr_time)  
    Redis::KeyValueStore.new(@key_spec, curr_time, {:group => :integration, :expire => 300}).set_key
    get :login, {:provider => "facebook", :uid => "12345678", :s => random_hash, :portal_type => @authorization[:provider]}
    response.should redirect_to '/facebook/support/home'
  end

  it "should redirect to support login page on timeout" do
    curr_time = ((DateTime.now.to_f * 1000 - 60001).to_i).to_s
    random_hash = Digest::MD5.hexdigest(curr_time)
    Redis::KeyValueStore.new(@key_spec, curr_time, {:group => :integration, :expire => 300}).set_key
    get :login, {:provider => "facebook", :uid => "12345678", :s => random_hash, :portal_type => @authorization[:provider]}
    response.should redirect_to support_login_url
  end

end