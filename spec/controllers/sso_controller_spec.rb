require 'spec_helper'
include MemcacheKeys

describe SsoController do
	integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @agent = add_test_agent(@account)
    @authorization = Factory.build(:authorization, :provider => "facebook",
                    :uid => "12345678", :user_id => @agent.id, :account_id => @account.id )
    @authorization.save(false)
    key_options = { :account_id => @account.id, :user_id => @agent.id, :provider => @authorization[:provider]}
    @key_spec = Redis::KeySpec.new(Redis::RedisKeys::SSO_AUTH_REDIRECT_OAUTH, key_options)
  end

  before(:each) do
    log_in(@agent)
  end

  it "should redirect to facebook home" do
    curr_time = ((DateTime.now.to_f * 1000).to_i).to_s
    random_hash = Digest::MD5.hexdigest(curr_time)
    Redis::KeyValueStore.new(@key_spec, curr_time, {:group => :integration, :expire => 300}).set_key
    get :login, {:provider => "facebook", :uid => "12345678", :s => random_hash, :portal_type => @authorization[:provider]}
    kv_store = Redis::KeyValueStore.new(@key_spec)
    kv_store.group = :integration
    kv_store.get_key.should be_nil
    response.should redirect_to '/facebook/support/home'
  end

  it "should redirect to support login page on timeout" do
    curr_time = ((DateTime.now.to_f * 1000 - 60001).to_i).to_s
    random_hash = Digest::MD5.hexdigest(curr_time)
    Redis::KeyValueStore.new(@key_spec, curr_time, {:group => :integration, :expire => 300}).set_key
    get :login, {:provider => "facebook", :uid => "12345678", :s => random_hash, :portal_type => @authorization[:provider]}
    response.should redirect_to support_login_url
  end

  it "should redirect to facebook auth url" do
    get :facebook
    current_portal = @account.portals.first
    response.should redirect_to "#{AppConfig['integrations_url'][Rails.env]}/auth/facebook?origin=id%3D#{@account.id}%26portal_id%3D#{current_portal.id}&state="
  end

end
