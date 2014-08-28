require 'spec_helper'
include MemcacheKeys

describe GoogleLoginController do
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