require 'spec_helper'

describe Support::LoginController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  it "should display login page" do
  	get :new
  	response.body.should =~ /Login to the support portal/
  	response.should be_success
  end

  it "should display login page for sso_enabled account" do
  	@account.sso_enabled = true
  	@account.save(false)
  	get :new
  	response.body.should =~ /redirected/
  	response.redirected_to.should =~ /host_url/
  end

  it "should allow user to login" do
  	post :create, :user_session=>{:email=>"sample@freshdesk.com", :password=>"test", :remember_me=>"0"}
  	response.body.should =~ /redirected/
  	response.body.should_not =~ /Login to the support portal/
  	response.redirected_to.should eql "/"
  end

  it "should not allow user to login with an incorrect password or if the user is a deleted user" do
  	customer = create_dummy_customer
  	customer.deleted = true
  	customer.save
  	post :create, :user_session=>{:email=>customer.email, :password=>"[FILTERED]", :remember_me=>"0"}
  	response.should be_success
  	response.body.should_not =~ /redirected/
  	response.body.should =~ /Login to the support portal/
  	response.redirected_to.should eql nil 
  end
end