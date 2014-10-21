require 'spec_helper'
include MemcacheKeys

describe GoogleLoginController do
	integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    log_in(@agent)
  end

  after(:each) do
    @account.make_current
  end

  it "should redirect to marketplace login" do
  	get :marketplace_login
  	response.should be_redirect
  end

  it "should create a customer with google request env details" do
    auth_hash = {:uid => "123456",
                 :info => {:name => @agent.name,
                           :email => @agent.email},
                 :extra => {:raw_info => {:hd => @account.full_domain}}
                }
    GoogleLoginController.any_instance.stubs(:auth_hash).returns(auth_hash)
    get :create_account_from_google
    response.should be_success
  end

  it "should redirect to portal login" do
  	get :portal_login
  	response.should be_redirect
  end

  it "should create a customer who logged in via portal" do
  	get :create_account_from_google, {:state => 'full_domain%3D' << @account.full_domain << '%26portal_url%3D' << @account.full_domain}
  	response.should be_redirect
  end

  it "should activate user and redirect if account is present" do
    auth_hash = {:uid => "123456",
                 :info => {:name => @agent.name,
                           :email => @agent.email},
                 :extra => {:raw_info => {:hd => @account.full_domain}}
                }
    GoogleLoginController.any_instance.stubs(:requested_portal_url).returns("freshpo.com")
    GoogleLoginController.any_instance.stubs(:uid).returns("123456")
    GoogleLoginController.any_instance.stubs(:email).returns(@agent.email)
    GoogleLoginController.any_instance.stubs(:login_account).returns(@account)
    get :create_account_from_google, {:state => 'full_domain%3D' << @account.full_domain << '%26portal_url%3D' << @account.full_domain}
    response.should be_redirect
  end

  it "should redirect to the Oauth while enabling gadget from market place" do
    get :google_gadget_login
    response.should be_redirect
  end

  # if a request contains gv_id then it means that it is from Google Gadget.
  it "should redirect to the portal login if gv_id is included in the state params" do
    auth_hash = {:uid => "123456",
                 :info => {:name => @agent.name,
                           :email => @agent.email},
                 :extra => {:raw_info => {:hd => @account.full_domain}}
                }
    google_viewer_id = "12345"
    generated_hash = Digest::MD5.hexdigest(DateTime.now.to_s + google_viewer_id)
    key_options = {:account_id => @account.id, :token => generated_hash}
    key_spec = Redis::KeySpec.new(Redis::RedisKeys::AUTH_REDIRECT_GOOGLE_OPENID, key_options)
    Redis::KeyValueStore.new(key_spec, google_viewer_id, {:group => :integration, :expire => 300}).set_key

    GoogleLoginController.any_instance.stubs(:requested_portal_url).returns("freshpo.com")
    GoogleLoginController.any_instance.stubs(:uid).returns("123456")
    GoogleLoginController.any_instance.stubs(:email).returns(@agent.email)
    GoogleLoginController.any_instance.stubs(:login_account).returns(@account)

    # params if passed via the server-rake then the decoding for urlencode seems to happen whereas if we stub the param by encoding then it doesn't decode and passes the encoded values as it is because of which CGI::parse doesn't work.
    get :create_account_from_google, {:state => 'full_domain=' << @account.full_domain << '&portal_url=' << @account.full_domain << "&gv_id=" << "#{generated_hash}"}
    Agent.find_by_user_id(@agent.id).google_viewer_id.should eql google_viewer_id
    response.should be_redirect
  end

  it "should find account domain if full_domain is set in params" do
    GoogleLoginController.any_instance.stubs(:actual_domain).returns(@account.full_domain)
    get :create_account_from_google, {:state => 'full_domain%3D' << @account.full_domain << '%26portal_url%3D' << @account.full_domain}
    response.should be_redirect
  end

  it "should create a customer who logged in via marketplace" do
  	get :create_account_from_google, {:state => 'full_domain%3D' << @account.full_domain << '%26portal_url%3D' << @account.full_domain}
  	response.should be_redirect
  end
end