require 'spec_helper'

describe UserSessionsController do
  self.use_transactional_fixtures = false 
  
  before(:each) do
    request.host = @account.full_domain
    request.user_agent = "Freshdesk_Native_Android"
    request.accept = "application/json"
    request.env['format'] = 'json'
  end

  before(:all) do
    @account.sso_enabled = false
    @account.save(:validate => false)

    @test_ticket = create_ticket({ :status => 2 }, create_group(@account, {:name => "Tickets"}))
  end

  it "should login an agent" do
    # @agent.password_salt = "8tIx1P2ZDIirkDijXly6";
    # @agent.crypted_password = "79a1bb96c3b4fbe540171e6b7a6d532e52f4365078d2ade1c1f082b35e9b2c858710b62b95b285ed1f620ca738c8d2c1ef7f138839ad23cd3320d595b3eeb9ac";
    @agent.password = "test"
    @agent.save!
    @agent.reload
    post :create, {"user_session"=>{"email"=>"#{@agent.email}", "password"=>"test", "remember_me"=>"0"}}
    json_response.should include("login","auth_token")
    json_response["auth_token"].should be_eql(@agent.single_access_token)
    json_response["login"].should be_eql("success")
  end

  it "should login an occasional agent" do
    user = add_test_agent(@account)
    user.agent.update_attributes(:occasional => true, :password => "test")
    @account.subscription.update_attributes(:state => "active")

    post :create, {"user_session"=>{"email"=>"#{user.email}", "password"=>"test", "remember_me"=>"0"}}
    
    json_response.should include("login","auth_token")
    json_response["auth_token"].should be_eql(user.single_access_token)
    json_response["login"].should be_eql("success")
  end

  it "should logout an agent" do
    request.env['HTTP_AUTHORIZATION'] =  ActionController::HttpAuthentication::Basic.encode_credentials(@agent.single_access_token,"X")
    get :destroy , {"format"=>"json", "registration_key"=>"some_key" }
    json_response.should include("logout")
    json_response["logout"].should be_eql("success")
  end

  # Negative Case
  
  it "should return error messages for wrong password" do
    post :create, {"user_session"=>{"email"=>"#{@agent.email}", "password"=>"wrong", "remember_me"=>"0"}}
    response.body.should include("'message' : 'Email/Password combination is not valid'")
    response.body.should include("'login':'failed'")
  end

  it "should not login an occasional agent when there are no daypasses left" do
    user = add_test_agent(@account)
    user.agent.update_attributes(:occasional => true, :password => "test")
    @account.subscription.update_attributes(:state => "active")
    @account.day_pass_config.update_attributes(:available_passes => 0)

    post :create, {"user_session"=>{"email"=>"#{user.email}", "password"=>"test", "remember_me"=>"0"}}    
    flash[:notice].should == I18n.t('agent.insufficient_day_pass')
  end

end