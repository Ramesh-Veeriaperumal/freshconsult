require 'spec_helper'

RSpec.configure do |c|
  c.include MemcacheKeys
end

RSpec.describe SsoController do
  self.use_transactional_fixtures = false

  before(:all) do
    @agent = add_test_agent(@account)
  end

  before(:each) do
    api_login
  end

  it "should create new user session if user hasn't logged in" do
    curr_time = ((DateTime.now.to_f * 1000).to_i).to_s
    key_options = {:domain => @account.full_domain,:uid => "12345678"}
    @google_oauth_key = Redis::KeySpec.new(Redis::RedisKeys::GOOGLE_OAUTH_SSO, key_options)
    Redis::KeyValueStore.new(@google_oauth_key, @agent.email, {:group => :integration, :expire => 300}).set_key
    get :google_login, {:domain => @account.full_domain, :uid => "12345678"}
    kv_store = Redis::KeyValueStore.new(@google_oauth_key)
    kv_store.group = :integration
    kv_store.get_key.should be_nil
    response.should redirect_to @account.full_url
    response.cookies['mobile_access_token'].should eql(@agent.single_access_token)
  end

end
