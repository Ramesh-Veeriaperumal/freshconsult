require 'spec_helper'

describe Support::LoginController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    create_features
  end

  after(:all) do
    create_features
  end

  def create_features
    @account.features.send(:google_signin).create
    @account.features.send(:facebook_signin).create
    @account.features.send(:twitter_signin).create
    @account.features.send(:signup_link).create
  end

  it "should display portal login page" do
    @account.sso_enabled = false
    @account.save(:validate => false)
    get :new
    response.body.should =~ /Login to the support portal/
    response.body.should =~ /...or login using/
    response.body.should =~ /Google/
    response.body.should =~ /Facebook/
    response.body.should =~ /Sign up with us/
    response.should be_success
  end

  it "should not display the restricted features in portal login page" do
    @account.sso_enabled = false
    @account.save(:validate => false)
    @account.features.send(:facebook_signin).destroy
    @account.features.send(:signup_link).destroy
    get :new
    @account.features.reload
    facebook_signin = @account.features.find_by_type("FacebookSigninFeature")
    facebook_signin.should be_nil
    signup_link = @account.features.find_by_type("SignupLinkFeature")
    signup_link.should be_nil
    response.body.should =~ /Google/
    response.body.should_not =~ /Facebook/
    response.body.should_not =~ /Sign up with us/
    response.body.should_not =~ /Once you sign up, you will have complete access to our solutions and FAQs/
    response.body.should =~ /Twitter/
    response.should be_succes
  end

  it "should display portal login page for sso_enabled account" do
    @account.sso_enabled = true
    @account.save(:validate => false)
    get :new
    response.body.should =~ /redirected/
    response.location.should =~ /host_url/
  end

  it "should allow user to login" do
    user = add_new_user(@account)
    user.password = "test"
    user.save
    post :create, :user_session=>{:email=> user.email, :password=>"test", :remember_me=>"0"}
    response.body.should =~ /redirected/
    response.body.should_not =~ /Login to the support portal/
    response.should redirect_to "/"
  end

  it "should not allow user to login with an incorrect password or if the user is a deleted user" do
    customer = create_dummy_customer
    customer.deleted = true
    customer.save
    post :create, :user_session=>{:email=>customer.email, :password=>"[FILTERED]", :remember_me=>"0"}
    response.should be_success
    response.body.should_not =~ /redirected/
    response.body.should =~ /Login to the support portal/
    response.should_not be_redirect 
  end
end