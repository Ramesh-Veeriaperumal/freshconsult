require_relative '../../api/test_helper'
require Rails.root.join('spec', 'support', 'user_helper.rb')

class UserSessionsControllerTest < ActionController::TestCase
  include UsersHelper
  include Redis::RedisKeys
  include Redis::OthersRedis

  def current_account
    Account.first
  end

  def current_user
    current_account.agents.first.user
  end

  def create_user_for_session
    user = add_test_agent(current_account)
    user.password = 'test567890'
    user.save!
    agent = user.agent
    user
  end

  def wrap_cname(params)
    { user_session: params }
  end

  def test_new_session_for_normal_login
    @request.path = '/login/normal'
    get :new
    assert_response 200
  end

  def test_new_session_for_sso_enabled_account
    Account.any_instance.stubs(:sso_enabled?).returns(true)
    get :new
    assert_response 302
    assert_includes response.redirect_url, current_account.host
  ensure
    Account.any_instance.unstub(:sso_enabled?)
  end

  def test_new_session_redirects_to_default_login
    get :new
    assert_response 302
    assert_includes response.redirect_url, '/support/login'
  end

  def test_create_redirects_to_host_url_after_successful_login
    user = create_user_for_session
    UserSession.any_instance.stubs(:save).returns(true)
    UserSession.any_instance.stubs(:record).returns(user)
    DataDogHelperMethods.stubs(:create_login_tags_and_send).returns(true)
    params_hash = { email: user.email, password: 'test567890' }
    post :create, construct_params({ format: 'html' }, params_hash)
    assert_response 302
    assert_includes response.redirect_url, current_account.host
  ensure
    UserSession.any_instance.unstub(:save)
    UserSession.any_instance.unstub(:record)
    DataDogHelperMethods.unstub(:create_login_tags_and_send)
  end

  def test_create_session_for_mobile
    user = create_user_for_session
    current_account.launch(:freshid)
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(false)
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(true)
    Account.any_instance.stubs(:all_technicians).returns(user)
    User.any_instance.stubs(:find_by_freshid_uuid).returns(user)
    Freshid::Login.any_instance.stubs(:authenticate_user).returns(Faker::Number.number(5))
    UserSession.any_instance.stubs(:save).returns(true)
    UserSession.any_instance.stubs(:record).returns(user)
    DataDogHelperMethods.stubs(:create_login_tags_and_send).returns(true)
    @controller.request.env['HTTP_USER_AGENT'] = { /#{AppConfig['app_name']}_Native/ => 'h' }
    params_hash = { email: user.email, password: 'test567890' }
    post :create, construct_params({ format: 'nmobile' }, params_hash)
    parsed_response = parse_response response.body
    assert_response 200
    assert_equal parsed_response['auth_token'], user.mobile_auth_token
  ensure
    current_account.rollback(:freshid)
    Account.any_instance.unstub(:all_technicians)
    User.any_instance.unstub(:find_by_freshid_uuid)
    Account.any_instance.unstub(:freshid_enabled?)
    Account.any_instance.unstub(:freshid_org_v2_enabled?)
    Account.any_instance.unstub(:freshid_integration_enabled?)
    Freshid::Login.any_instance.unstub(:authenticate_user)
    UserSession.any_instance.unstub(:save)
    UserSession.any_instance.unstub(:record)
    DataDogHelperMethods.unstub(:create_login_tags_and_send)
  end

  def test_create_session_for_mobile_with_invalid_freshid_uuid
    user = create_user_for_session
    current_account.launch(:freshid)
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(false)
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(true)
    Freshid::Login.any_instance.stubs(:authenticate_user).returns(Faker::Number.number(5))
    UserSession.any_instance.stubs(:save).returns(true)
    UserSession.any_instance.stubs(:record).returns(user)
    DataDogHelperMethods.stubs(:create_login_tags_and_send).returns(true)
    @controller.request.env['HTTP_USER_AGENT'] = { /#{AppConfig['app_name']}_Native/ => 'h' }
    params_hash = { email: user.email, password: 'test567890' }
    post :create, construct_params({ format: 'nmobile' }, params_hash)
    parsed_response = parse_response response.body
    assert_response 200
    assert_nil parsed_response['auth_token']
  ensure
    current_account.rollback(:freshid)
    Account.any_instance.unstub(:freshid_enabled?)
    Account.any_instance.unstub(:freshid_org_v2_enabled?)
    Account.any_instance.unstub(:freshid_integration_enabled?)
    Freshid::Login.any_instance.unstub(:authenticate_user)
    UserSession.any_instance.unstub(:save)
    UserSession.any_instance.unstub(:record)
    DataDogHelperMethods.unstub(:create_login_tags_and_send)
  end

  def test_session_creation_for_customer_in_mobile
    user = add_new_user(current_account)
    current_account.launch(:freshid)
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(false)
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(true)
    Account.any_instance.stubs(:all_technicians).returns(user)
    User.any_instance.stubs(:find_by_freshid_uuid).returns(user)
    Freshid::Login.any_instance.stubs(:authenticate_user).returns(Faker::Number.number(5))
    UserSession.any_instance.stubs(:save).returns(true)
    UserSession.any_instance.stubs(:record).returns(user)
    DataDogHelperMethods.stubs(:create_login_tags_and_send).returns(true)
    @controller.request.env['HTTP_USER_AGENT'] = { /#{AppConfig['app_name']}_Native/ => 'h' }
    params_hash = { email: user.email, password: 'test567890' }
    post :create, construct_params({ format: 'nmobile' }, params_hash)
    parsed_response = parse_response response.body
    assert_response 200
    assert_equal parsed_response['login'], 'customer'
  ensure
    current_account.rollback(:freshid)
    Account.any_instance.unstub(:all_technicians)
    User.any_instance.unstub(:find_by_freshid_uuid)
    Account.any_instance.unstub(:freshid_enabled?)
    Account.any_instance.unstub(:freshid_org_v2_enabled?)
    Account.any_instance.unstub(:freshid_integration_enabled?)
    Freshid::Login.any_instance.unstub(:authenticate_user)
    UserSession.any_instance.unstub(:save)
    UserSession.any_instance.unstub(:record)
    DataDogHelperMethods.unstub(:create_login_tags_and_send)
  end

  def test_session_creation_for_password_expired_customer_in_mobile
    user = create_user_for_session
    current_account.launch(:freshid)
    User.any_instance.stubs(:password_expired?).returns(true)
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(false)
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(true)
    Account.any_instance.stubs(:all_technicians).returns(user)
    User.any_instance.stubs(:find_by_freshid_uuid).returns(user)
    Freshid::Login.any_instance.stubs(:authenticate_user).returns(Faker::Number.number(5))
    UserSession.any_instance.stubs(:save).returns(true)
    UserSession.any_instance.stubs(:record).returns(user)
    DataDogHelperMethods.stubs(:create_login_tags_and_send).returns(true)
    @controller.request.env['HTTP_USER_AGENT'] = { /#{AppConfig['app_name']}_Native/ => 'h' }
    params_hash = { email: user.email, password: 'test567890' }
    post :create, construct_params({ format: 'nmobile' }, params_hash)
    parsed_response = parse_response response.body
    assert_response 200
    assert_equal parsed_response['login'], 'failed'
  ensure
    current_account.rollback(:freshid)
    User.any_instance.unstub(:password_expired?)
    Account.any_instance.unstub(:all_technicians)
    User.any_instance.unstub(:find_by_freshid_uuid)
    Account.any_instance.unstub(:freshid_enabled?)
    Account.any_instance.unstub(:freshid_org_v2_enabled?)
    Account.any_instance.unstub(:freshid_integration_enabled?)
    Freshid::Login.any_instance.unstub(:authenticate_user)
    UserSession.any_instance.unstub(:save)
    UserSession.any_instance.unstub(:record)
    DataDogHelperMethods.unstub(:create_login_tags_and_send)
  end

  def test_session_creation_failure_with_html_response
    user = create_user_for_session
    UserSession.any_instance.stubs(:save).returns(false)
    params_hash = { email: user.email, password: 'test567890' }
    post :create, construct_params({ format: 'html' }, params_hash)
    assert_response 302
    assert_includes response.redirect_url, '/support/login'
  ensure
    UserSession.any_instance.unstub(:save)
  end

  def test_session_creation_fails_for_empty_email
    params_hash = { password: 'test567890' }
    post :create, construct_params({ format: 'nmobile' }, params_hash)
    assert_response 200
    parsed_response = parse_response response.body
    assert_equal parsed_response['login'], 'failed'
    assert_equal parsed_response['message'], 'The email and password you entered does not match'
  end

  def test_user_session_destroy
    Agent.any_instance.stubs(:toggle_availability?).returns(true)
    Agent.any_instance.stubs(:available?).returns(true)
    Agent.any_instance.stubs(:update_attribute).returns(true)
    delete :destroy, construct_params(format: 'html')
    assert_response 302
  ensure
    Agent.any_instance.unstub(:toggle_availability?)
    Agent.any_instance.unstub(:available?)
    Agent.any_instance.unstub(:update_attribute)
  end

  def test_session_destroy_in_mobile
    Agent.any_instance.stubs(:toggle_availability?).returns(true)
    Agent.any_instance.stubs(:available?).returns(true)
    Agent.any_instance.stubs(:update_attribute).returns(true)
    delete :destroy, construct_params(format: 'nmobile')
    assert_response 200
    assert_equal JSON.parse(response.body)['logout'], 'success'
  ensure
    Agent.any_instance.unstub(:toggle_availability?)
    Agent.any_instance.unstub(:available?)
    Agent.any_instance.unstub(:update_attribute)
  end

  def test_user_session_destroy_for_freshid_agent
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(false)
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(true)
    delete :destroy, construct_params(format: 'html')
    assert_response 302
  ensure
    Account.any_instance.unstub(:freshid_enabled?)
    Account.any_instance.unstub(:freshid_org_v2_enabled?)
    Account.any_instance.unstub(:freshid_integration_enabled?)
  end

  def test_session_destroy_with_oauth_enabled
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(false)
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(true)
    Account.any_instance.stubs(:oauth2_enabled?).returns(true)
    Account.any_instance.stubs(:sso_enabled?).returns(true)
    Account.any_instance.stubs(:agent_oauth2_sso_enabled?).returns(true)
    delete :destroy, construct_params(format: 'html')
    assert_response 302
  ensure
    Account.any_instance.unstub(:oauth2_enabled?)
    Account.any_instance.unstub(:freshid_enabled?)
    Account.any_instance.unstub(:freshid_org_v2_enabled?)
    Account.any_instance.unstub(:freshid_integration_enabled?)
    Account.any_instance.unstub(:sso_enabled?)
    Account.any_instance.unstub(:agent_oauth2_sso_enabled?)
  end

  def test_session_destroy_with_agent_saml_auth_enabled
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(false)
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(true)
    Account.any_instance.stubs(:freshid_saml_enabled?).returns(true)
    Account.any_instance.stubs(:sso_enabled?).returns(true)
    Account.any_instance.stubs(:agent_freshid_saml_sso_enabled?).returns(true)
    delete :destroy, construct_params(format: 'html')
    assert_response 302
  ensure
    Account.any_instance.unstub(:freshid_enabled?)
    Account.any_instance.unstub(:freshid_org_v2_enabled?)
    Account.any_instance.unstub(:freshid_integration_enabled?)
    Account.any_instance.unstub(:freshid_saml_enabled?)
    Account.any_instance.unstub(:sso_enabled?)
    Account.any_instance.unstub(:agent_freshid_saml_sso_enabled?)
  end

  def test_session_destroy_for_customer
    user = add_new_user(current_account)
    @controller.stubs(:current_user).returns(user)
    Agent.any_instance.stubs(:toggle_availability?).returns(true)
    Agent.any_instance.stubs(:available?).returns(true)
    Agent.any_instance.stubs(:update_attribute).returns(true)
    delete :destroy, construct_params(format: 'html')
    assert_response 302
  ensure
    @controller.unstub(:current_user)
    Agent.any_instance.unstub(:toggle_availability?)
    Agent.any_instance.unstub(:available?)
    Agent.any_instance.unstub(:update_attribute)
  end

  def test_session_destroy_for_customer_with_oauth_enabled
    user = add_new_user(current_account)
    @controller.stubs(:current_user).returns(user)
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(false)
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(true)
    Account.any_instance.stubs(:oauth2_enabled?).returns(true)
    Account.any_instance.stubs(:sso_enabled?).returns(true)
    Account.any_instance.stubs(:customer_oauth2_sso_enabled?).returns(true)
    delete :destroy, construct_params(format: 'html')
    assert_response 302
  ensure
    @controller.unstub(:current_user)
    Account.any_instance.unstub(:oauth2_enabled?)
    Account.any_instance.unstub(:freshid_enabled?)
    Account.any_instance.unstub(:freshid_org_v2_enabled?)
    Account.any_instance.unstub(:freshid_integration_enabled?)
    Account.any_instance.unstub(:sso_enabled?)
    Account.any_instance.unstub(:customer_oauth2_sso_enabled?)
  end

  def test_session_destroy_for_customer_with_freshid_saml_enabled
    user = add_new_user(current_account)
    @controller.stubs(:current_user).returns(user)
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(false)
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(true)
    Account.any_instance.stubs(:freshid_saml_enabled?).returns(true)
    Account.any_instance.stubs(:sso_enabled?).returns(true)
    Account.any_instance.stubs(:customer_freshid_saml_sso_enabled?).returns(true)
    delete :destroy, construct_params(format: 'html')
    assert_response 302
  ensure
    @controller.unstub(:current_user)
    Account.any_instance.unstub(:freshid_enabled?)
    Account.any_instance.unstub(:freshid_org_v2_enabled?)
    Account.any_instance.unstub(:freshid_integration_enabled?)
    Account.any_instance.unstub(:freshid_saml_enabled?)
    Account.any_instance.unstub(:sso_enabled?)
    Account.any_instance.unstub(:customer_freshid_saml_sso_enabled?)
  end

  def test_agent_login_for_logged_in_user
    get :agent_login
    assert_response 302
    assert_includes response.redirect_url, '/helpdesk'
  end

  def test_agent_login_for_logged_out_user
    @controller.stubs(:current_user).returns(nil)
    get :agent_login
    assert_response 302
    assert_includes response.redirect_url, '/support/login'
  ensure
    @controller.unstub(:current_user)
  end

  def test_agent_login_when_sso_enabled_for_logged_in_user
    Account.any_instance.stubs(:oauth2_enabled?).returns(true)
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(false)
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(true)
    Account.any_instance.stubs(:sso_enabled?).returns(true)
    Account.any_instance.stubs(:agent_oauth2_sso_enabled?).returns(true)
    get :agent_login
    assert_response 302
    assert_includes response.redirect_url, '/helpdesk'
  ensure
    Account.any_instance.unstub(:oauth2_enabled?)
    Account.any_instance.unstub(:freshid_enabled?)
    Account.any_instance.unstub(:freshid_org_v2_enabled?)
    Account.any_instance.unstub(:freshid_integration_enabled?)
    Account.any_instance.unstub(:sso_enabled?)
    Account.any_instance.unstub(:agent_oauth2_sso_enabled?)
  end

  def test_agent_login_when_sso_enabled_for_logged_out_user
    @controller.stubs(:current_user).returns(nil)
    Account.any_instance.stubs(:oauth2_enabled?).returns(true)
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(false)
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(true)
    Account.any_instance.stubs(:sso_enabled?).returns(true)
    Account.any_instance.stubs(:agent_oauth2_sso_enabled?).returns(true)
    get :agent_login
    assert_response 302
    assert_includes response.redirect_url, '/oauth/authorize'
  ensure
    @controller.unstub(:current_user)
    Account.any_instance.unstub(:oauth2_enabled?)
    Account.any_instance.unstub(:freshid_enabled?)
    Account.any_instance.unstub(:freshid_org_v2_enabled?)
    Account.any_instance.unstub(:freshid_integration_enabled?)
    Account.any_instance.unstub(:sso_enabled?)
    Account.any_instance.unstub(:agent_oauth2_sso_enabled?)
  end

  def test_customer_login_for_logged_in_customer
    get :customer_login
    assert_response 302
    assert_includes response.redirect_url, '/support'
  end

  def test_customer_login_for_logged_out_customer
    @controller.stubs(:current_user).returns(nil)
    get :customer_login
    assert_response 302
    assert_includes response.redirect_url, '/support/login'
  ensure
    @controller.unstub(:current_user)
  end

  def test_customer_login_when_sso_enabled_for_logged_in_customer
    Account.any_instance.stubs(:oauth2_enabled?).returns(true)
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(false)
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(true)
    Account.any_instance.stubs(:sso_enabled?).returns(true)
    Account.any_instance.stubs(:customer_oauth2_sso_enabled?).returns(true)
    get :customer_login
    assert_response 302
    assert_includes response.redirect_url, '/support/home'
  ensure
    Account.any_instance.unstub(:oauth2_enabled?)
    Account.any_instance.unstub(:freshid_enabled?)
    Account.any_instance.unstub(:freshid_org_v2_enabled?)
    Account.any_instance.unstub(:freshid_integration_enabled?)
    Account.any_instance.unstub(:sso_enabled?)
    Account.any_instance.unstub(:customer_oauth2_sso_enabled?)
  end

  def test_customer_login_when_sso_enabled_for_logged_out_customer
    @controller.stubs(:current_user).returns(nil)
    Account.any_instance.stubs(:oauth2_enabled?).returns(true)
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(false)
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(true)
    Account.any_instance.stubs(:sso_enabled?).returns(true)
    Account.any_instance.stubs(:customer_oauth2_sso_enabled?).returns(true)
    get :customer_login
    assert_response 302
    assert_includes response.redirect_url, '/oauth/authorize'
  ensure
    @controller.unstub(:current_user)
    Account.any_instance.unstub(:oauth2_enabled?)
    Account.any_instance.unstub(:freshid_enabled?)
    Account.any_instance.unstub(:freshid_org_v2_enabled?)
    Account.any_instance.unstub(:freshid_integration_enabled?)
    Account.any_instance.unstub(:sso_enabled?)
    Account.any_instance.unstub(:customer_oauth2_sso_enabled?)
  end

  def test_show
    get :show
    assert_response 302
  end

  def test_freshid_session_destroy
    get :freshid_destroy, redirect_uri: '/login'
    assert_response 302
    assert_includes response.redirect_url, '/login'
  end

  def test_freshid_session_destroy_for_sso_enabled_user
    Account.any_instance.stubs(:sso_enabled?).returns(true)
    Account.any_instance.stubs(:sso_logout_url).returns('/login')
    get :freshid_destroy
    assert_response 302
    assert_includes response.redirect_url, '/login'
  ensure
    Account.any_instance.unstub(:sso_enabled?)
    Account.any_instance.unstub(:sso_logout_url)
  end

  def test_freshid_session_destroy_raises_exception
    Account.any_instance.stubs(:try).raises(ShardNotFound)
    get :freshid_destroy, redirect_uri: '/login'
    assert_response 302
    assert_includes response.redirect_url, '/login'
  ensure
    Account.any_instance.unstub(:try)
  end

  def test_signup_complete_for_active_freshid_agent
    user = create_user_for_session
    User.any_instance.stubs(:active_freshid_agent?).returns(true)
    get :signup_complete, token: user.perishable_token
    assert_response 302
    assert_includes response.cookies['return_to'], '/a/getstarted'
  ensure
    User.any_instance.unstub(:active_freshid_agent?)
  end

  def test_signup_complete_for_freshid_enabled_account
    user = add_new_user(current_account)
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(false)
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(true)
    UserSession.any_instance.stubs(:save).returns(true)
    UserEmail.any_instance.stubs(:update_attributes).returns(true)
    User.any_instance.stubs(:deliver_admin_activation).returns(true)
    User.any_instance.stubs(:reset_perishable_token!).returns(true)
    get :signup_complete, token: user.perishable_token
    assert_response 302
  ensure
    Account.any_instance.unstub(:freshid_enabled?)
    Account.any_instance.unstub(:freshid_org_v2_enabled?)
    Account.any_instance.unstub(:freshid_integration_enabled?)
    UserSession.any_instance.unstub(:save)
    UserEmail.any_instance.unstub(:update_attributes)
    User.any_instance.unstub(:deliver_admin_activation)
    User.any_instance.unstub(:reset_perishable_token!)
  end

  def test_signup_complete_for_invalid_user
    get :signup_complete, token: Faker::Number.number(10)
    assert_response 302
    assert_includes response.redirect_url, '/login'
  end

  def test_signup_complete_without_valid_params
    user = add_new_user(current_account)
    UserSession.any_instance.stubs(:save).returns(false)
    get :signup_complete, token: user.perishable_token
    assert_response 404
  ensure
    UserSession.any_instance.unstub(:save)
  end

  def test_sso_login_without_sso_enabled
    post :sso_login, name: Faker::Name.name, email: Faker::Internet.email, timestamp: Time.now.to_i
    assert_response 302
    assert_includes response.redirect_url, '/login/normal'
  end

  def test_sso_login
    name = Faker::Name.name
    email = Faker::Internet.email
    time = Time.now.to_i
    params = {
      name: name,
      email: email
    }
    hash = Digest::MD5.hexdigest(name + email + current_account.shared_secret)
    remove_others_redis_key(hash)
    user = add_new_user(current_account, email: email)
    Account.any_instance.stubs(:allow_sso_login?).returns(true)
    Account.any_instance.stubs(:launched?).returns(true)
    User.any_instance.stubs(:save).returns(true)
    UserSession.any_instance.stubs(:save).returns(true)
    DataDogHelperMethods.stubs(:create_login_tags_and_send).returns(true)
    @controller.request.env['HTTP_USER_AGENT'] = { /#{AppConfig['app_name']}_Native/ => 'h' }
    post :sso_login, name: name, email: email, hash: hash, redirect_to: '/helpdesk'
    assert_response 302
    assert_includes response.redirect_url, '/helpdesk'
  ensure
    Account.any_instance.unstub(:allow_sso_login?)
    Account.any_instance.unstub(:launched?)
    User.any_instance.unstub(:save)
    UserSession.any_instance.unstub(:save)
    DataDogHelperMethods.unstub(:create_login_tags_and_send)
  end

  def test_sso_login_with_redis_key_set
    name = Faker::Name.name
    email = Faker::Internet.email
    time = Time.now.to_i
    params = {
      name: name,
      email: email
    }
    hash = Digest::MD5.hexdigest(name + current_account.shared_secret + email)
    set_others_redis_key(hash, 'test')
    Account.any_instance.stubs(:allow_sso_login?).returns(true)
    post :sso_login, name: name, email: email, hash: hash, timestamp: time
    assert_response 302
    assert_includes response.redirect_url, '/login/normal'
  ensure
    remove_others_redis_key(hash)
    Account.any_instance.unstub(:allow_sso_login?)
  end

  def test_sso_login_when_mandatory_params_not_present
    Account.any_instance.stubs(:allow_sso_login?).returns(true)
    post :sso_login
    assert_response 302
    assert_includes response.redirect_url, '/login/normal'
  ensure
    Account.any_instance.unstub(:allow_sso_login?)
  end

  def test_sso_login_with_timestamp_not_between_sso_drift_time
    name = Faker::Name.name
    email = Faker::Internet.email
    time = Time.now.getutc.to_i + 35
    params = {
      name: name,
      email: email
    }
    hash = Digest::MD5.hexdigest(name + current_account.shared_secret + email)
    remove_others_redis_key(hash)
    Account.any_instance.stubs(:allow_sso_login?).returns(true)
    post :sso_login, name: name, email: email, hash: hash, timestamp: time
    assert_response 302
    assert_includes response.redirect_url, '/login/normal'
  ensure
    Account.any_instance.unstub(:allow_sso_login?)
  end

  def test_sso_login_for_deleted_user
    name = Faker::Name.name
    email = Faker::Internet.email
    time = Time.now.to_i
    params = {
      name: name,
      email: email
    }
    hash = Digest::MD5.hexdigest(name + current_account.shared_secret + email)
    remove_others_redis_key(hash)
    Account.any_instance.stubs(:allow_sso_login?).returns(true)
    user = add_new_user(current_account, email: email, deleted: 1)
    post :sso_login, name: name, email: email, hash: hash
    assert_response 302
    assert_includes response.redirect_url, '/login/normal'
  ensure
    Account.any_instance.unstub(:allow_sso_login?)
  end

  def test_sso_login_for_new_user
    name = Faker::Name.name
    email = Faker::Internet.email
    time = Time.now.to_i
    params = {
      name: name,
      email: email
    }
    hash = Digest::MD5.hexdigest(name + current_account.shared_secret + email)
    remove_others_redis_key(hash)
    Account.any_instance.stubs(:allow_sso_login?).returns(true)
    User.any_instance.stubs(:save).returns(true)
    UserSession.any_instance.stubs(:save).returns(true)
    DataDogHelperMethods.stubs(:create_login_tags_and_send).returns(true)
    post :sso_login, name: name, email: email, hash: hash, redirect_to: '/helpdesk'
    assert_response 302
    assert_includes response.redirect_url, '/helpdesk'
  ensure
    Account.any_instance.unstub(:allow_sso_login?)
    User.any_instance.unstub(:save)
    UserSession.any_instance.unstub(:save)
    DataDogHelperMethods.unstub(:create_login_tags_and_send)
  end

  def test_sso_login_with_user_save_failure
    name = Faker::Name.name
    email = Faker::Internet.email
    time = Time.now.to_i
    params = {
      name: name,
      email: email
    }
    hash = Digest::MD5.hexdigest(name + current_account.shared_secret + email)
    remove_others_redis_key(hash)
    Account.any_instance.stubs(:allow_sso_login?).returns(true)
    User.any_instance.stubs(:save).returns(false)
    UserSession.any_instance.stubs(:save).returns(true)
    DataDogHelperMethods.stubs(:create_login_tags_and_send).returns(true)
    post :sso_login, name: name, email: email, hash: hash
    assert_response 302
    assert_includes response.redirect_url, '/login/normal'
  ensure
    Account.any_instance.unstub(:allow_sso_login?)
    User.any_instance.unstub(:save)
    UserSession.any_instance.unstub(:save)
    DataDogHelperMethods.unstub(:create_login_tags_and_send)
  end

  def test_sso_login_without_day_pass
    user = add_test_agent
    agent = user.agent
    agent.occasional = true
    agent.save
    user.reload
    name = Faker::Name.name
    email = Faker::Internet.email
    time = Time.now.to_i
    params = {
      name: name,
      email: email
    }
    hash = Digest::MD5.hexdigest(name + email + current_account.shared_secret)
    remove_others_redis_key(hash)
    @controller.stubs(:current_user).returns(user)
    Account.any_instance.stubs(:allow_sso_login?).returns(true)
    User.any_instance.stubs(:day_pass_granted_on).returns(nil)
    Subscription.any_instance.stubs(:trial?).returns(false)
    User.any_instance.stubs(:save).returns(true)
    UserSession.any_instance.stubs(:save).returns(true)
    DataDogHelperMethods.stubs(:create_login_tags_and_send).returns(true)
    Account.any_instance.stubs(:launched?).returns(true)
    DayPassConfig.any_instance.stubs(:grant_day_pass).returns(false)
    get :sso_login, name: name, email: email, hash: hash, redirect_to: '/helpdesk'
    assert_response 302
    assert_includes response.redirect_url, '/login/normal'
  ensure
    remove_others_redis_key(hash)
    Account.any_instance.unstub(:allow_sso_login?)
    User.any_instance.unstub(:day_pass_granted_on)
    Subscription.any_instance.unstub(:trial?)
    User.any_instance.unstub(:save)
    UserSession.any_instance.unstub(:save)
    DataDogHelperMethods.unstub(:create_login_tags_and_send)
    Account.any_instance.unstub(:launched?)
    DayPassConfig.any_instance.unstub(:grant_day_pass)
  end

  def test_sso_login_with_invalid_sso_hash
    hash = Faker::Lorem.word
    remove_others_redis_key(hash)
    Account.any_instance.stubs(:allow_sso_login?).returns(true)
    get :sso_login, name: Faker::Name.name, email: Faker::Internet.email, hash: hash
    assert_response 302
    assert_includes response.redirect_url, '/login/normal'
  ensure
    remove_others_redis_key(hash)
    Account.any_instance.unstub(:allow_sso_login?)
  end

  def test_jwt_login
    user = add_new_user(current_account)
    jwt_hash = {
      'exp' => Time.now.to_i + 200,
      'iat' => Time.now.to_i - 200,
      'user' => {
        'name' => Faker::Name.name,
        'email' => user.email,
        'user_companies' => [Faker::Name.name, Faker::Name.name]
      }
    }
    Account.any_instance.stubs(:allow_sso_login?).returns(true)
    JWT.stubs(:decode).returns([jwt_hash])
    User.any_instance.stubs(:save).returns(true)
    Account.any_instance.stubs(:multiple_user_companies_enabled?).returns(true)
    UserSession.any_instance.stubs(:save).returns(true)
    DataDogHelperMethods.stubs(:create_login_tags_and_send).returns(true)
    @controller.request.env['HTTP_USER_AGENT'] = { /#{AppConfig['app_name']}_Native/ => 'h' }
    get :jwt_sso_login, jwt_token: Faker::Lorem.word, redirect_to: '/helpdesk'
    assert_response 302
    assert_includes response.redirect_url, '/helpdesk'
  ensure
    Account.any_instance.unstub(:allow_sso_login?)
    JWT.unstub(:decode)
    User.any_instance.unstub(:save)
    Account.any_instance.unstub(:multiple_user_companies_enabled?)
    UserSession.any_instance.unstub(:save)
    DataDogHelperMethods.unstub(:create_login_tags_and_send)
  end

  def test_jwt_login_with_empty_expiry_token
    user = add_new_user(current_account)
    jwt_hash = {
      'user' => {
        'name' => Faker::Name.name,
        'email' => user.email,
        'user_companies' => [Faker::Name.name, Faker::Name.name]
      }
    }
    Account.any_instance.stubs(:allow_sso_login?).returns(true)
    JWT.stubs(:decode).returns([jwt_hash])
    get :jwt_sso_login, jwt_token: Faker::Lorem.word, redirect_to: '/helpdesk'
    assert_response 302
    assert_includes response.redirect_url, '/login/normal'
  ensure
    Account.any_instance.unstub(:allow_sso_login?)
    JWT.unstub(:decode)
  end

  def test_jwt_login_with_expiry_time_lesser_than_max_expiry_time
    user = add_new_user(current_account)
    jwt_hash = {
      'exp' => Time.now.to_i + 900,
      'iat' => Time.now.to_i - 100,
      'user' => {
        'name' => Faker::Name.name,
        'email' => user.email,
        'user_companies' => [Faker::Name.name, Faker::Name.name]
      }
    }
    Account.any_instance.stubs(:allow_sso_login?).returns(true)
    JWT.stubs(:decode).returns([jwt_hash])
    get :jwt_sso_login, jwt_token: Faker::Lorem.word, redirect_to: '/helpdesk'
    assert_response 302
    assert_includes response.redirect_url, '/login/normal'
  ensure
    Account.any_instance.unstub(:allow_sso_login?)
    JWT.unstub(:decode)
  end

  def test_jwt_login_without_user_email
    user = add_new_user(current_account)
    jwt_hash = {
      'exp' => Time.now.to_i + 200,
      'iat' => Time.now.to_i - 200,
      'user' => {
        'name' => Faker::Name.name,
        'user_companies' => [Faker::Name.name, Faker::Name.name]
      }
    }
    Account.any_instance.stubs(:allow_sso_login?).returns(true)
    JWT.stubs(:decode).returns([jwt_hash])
    get :jwt_sso_login, jwt_token: Faker::Lorem.word, redirect_to: '/helpdesk'
    assert_response 302
    assert_includes response.redirect_url, '/login/normal'
  ensure
    Account.any_instance.unstub(:allow_sso_login?)
    JWT.unstub(:decode)
  end

  def test_jwt_login_raises_jwt_decode_exception
    user = add_new_user(current_account)
    jwt_hash = {
      'exp' => Time.now.to_i + 200,
      'iat' => Time.now.to_i - 200,
      'user' => {
        'name' => Faker::Name.name,
        'email' => user.email,
        'user_companies' => [Faker::Name.name, Faker::Name.name]
      }
    }
    token = JWT.encode jwt_hash, 'wrong_secret', 'HS512'
    Account.any_instance.stubs(:allow_sso_login?).returns(true)
    get :jwt_sso_login, jwt_token: token, redirect_to: '/helpdesk'
    assert_response 302
    assert_includes response.redirect_url, '/login/normal'
  ensure
    Account.any_instance.unstub(:allow_sso_login?)
  end

  def test_jwt_login_raises_normal_exception
    Account.any_instance.stubs(:allow_sso_login?).returns(true)
    JWT.stubs(:decode).raises(StandardError)
    get :jwt_sso_login, jwt_token: Faker::Lorem.word, redirect_to: '/helpdesk'
    assert_response 302
    assert_includes response.redirect_url, '/login/normal'
  ensure
    Account.any_instance.unstub(:allow_sso_login?)
    JWT.unstub(:decode)
  end

  def test_jwt_login_for_deleted_user
    user = add_new_user(current_account)
    user.deleted = true
    user.save
    user.reload
    jwt_hash = {
      'exp' => Time.now.to_i + 200,
      'iat' => Time.now.to_i - 200,
      'user' => {
        'name' => Faker::Name.name,
        'email' => user.email,
        'user_companies' => [Faker::Name.name, Faker::Name.name]
      }
    }
    @controller.stubs(:current_user).returns(user)
    Account.any_instance.stubs(:allow_sso_login?).returns(true)
    JWT.stubs(:decode).returns([jwt_hash])
    get :jwt_sso_login, jwt_token: Faker::Lorem.word, redirect_to: '/helpdesk'
    assert_response 302
    assert_includes response.redirect_url, '/login/normal'
  ensure
    @controller.unstub(:current_user)
    Account.any_instance.unstub(:allow_sso_login?)
    JWT.unstub(:decode)
  end

  def test_jwt_login_for_occasional_agent_without_day_pass
    user = add_test_agent
    agent = user.agent
    agent.occasional = true
    agent.save
    user.reload
    jwt_hash = {
      'exp' => Time.now.to_i + 200,
      'iat' => Time.now.to_i - 200,
      'user' => {
        'name' => Faker::Name.name,
        'email' => user.email,
        'user_companies' => [Faker::Name.name, Faker::Name.name]
      }
    }
    @controller.stubs(:current_user).returns(user)
    Account.any_instance.stubs(:allow_sso_login?).returns(true)
    JWT.stubs(:decode).returns([jwt_hash])
    User.any_instance.stubs(:save).returns(true)
    UserSession.any_instance.stubs(:save).returns(true)
    DataDogHelperMethods.stubs(:create_login_tags_and_send).returns(true)
    User.any_instance.stubs(:day_pass_granted_on).returns(nil)
    Subscription.any_instance.stubs(:trial?).returns(false)
    DayPassConfig.any_instance.stubs(:grant_day_pass).returns(false)
    get :jwt_sso_login, jwt_token: Faker::Lorem.word, redirect_to: '/helpdesk'
    assert_response 302
    assert_includes response.redirect_url, '/login/normal'
  ensure
    @controller.unstub(:current_user)
    Account.any_instance.unstub(:allow_sso_login?)
    JWT.unstub(:decode)
    User.any_instance.unstub(:save)
    UserSession.any_instance.unstub(:save)
    DataDogHelperMethods.unstub(:create_login_tags_and_send)
    User.any_instance.stubs(:day_pass_granted_on).returns(nil)
    Subscription.any_instance.stubs(:trial?).returns(false)
    DayPassConfig.any_instance.stubs(:grant_day_pass).returns(false)
  end

  def test_jwt_login_when_session_save_fails
    user = add_new_user(current_account)
    jwt_hash = {
      'exp' => Time.now.to_i + 200,
      'iat' => Time.now.to_i - 200,
      'user' => {
        'name' => Faker::Name.name,
        'email' => user.email,
        'user_companies' => [Faker::Name.name, Faker::Name.name]
      }
    }
    Account.any_instance.stubs(:allow_sso_login?).returns(true)
    JWT.stubs(:decode).returns([jwt_hash])
    User.any_instance.stubs(:save).returns(true)
    UserSession.any_instance.stubs(:save).returns(false)
    get :jwt_sso_login, jwt_token: Faker::Lorem.word, redirect_to: '/helpdesk'
    assert_response 302
    assert_includes response.redirect_url, '/login/normal'
  ensure
    Account.any_instance.unstub(:allow_sso_login?)
    JWT.unstub(:decode)
    User.any_instance.unstub(:save)
    UserSession.any_instance.unstub(:save)
  end

  def test_jwt_login_raises_sso_field_validation_error
    user = add_new_user(current_account)
    jwt_hash = {
      'exp' => Time.now.to_i + 200,
      'iat' => Time.now.to_i - 200,
      'user' => {
        'name' => 1,
        'email' => user.email
      }
    }
    @controller.stubs(:current_user).returns(user)
    @controller.stubs(:check_jwt_required_fields).returns(true)
    Account.any_instance.stubs(:allow_sso_login?).returns(true)
    JWT.stubs(:decode).returns([jwt_hash])
    get :jwt_sso_login, jwt_token: Faker::Lorem.word, redirect_to: '/helpdesk'
    assert_response 302
    assert_includes response.redirect_url, '/login/normal'
  ensure
    @controller.unstub(:current_user)
    @controller.unstub(:check_jwt_required_fields)
    Account.any_instance.unstub(:allow_sso_login?)
    JWT.unstub(:decode)
  end

  def test_saml_login_with_relay_state_url
    user_name = Faker::Name.name
    email = Faker::Internet.email
    redirect_url = Faker::Internet.url
    saml_response = SsoUtil::SAMLResponse.new(true, user_name, email, '', '', '', '', [], '')
    @controller.stubs(:validate_saml_response).returns(saml_response)
    User.any_instance.stubs(:save).returns(true)
    UserSession.any_instance.stubs(:save).returns(true)
    get :saml_login, RelayState: redirect_url
    assert_response 302
    assert_equal response.redirect_url, redirect_url
  ensure
    @controller.unstub(:validate_saml_response)
    User.any_instance.unstub(:save)
    UserSession.any_instance.unstub(:save)
  end

  def test_saml_login_without_relay_state_url
    user = add_new_user(current_account)
    user_name = Faker::Name.name
    email = user.email
    saml_response = SsoUtil::SAMLResponse.new(true, user_name, email, '', '', '', '', [], '')
    @controller.stubs(:validate_saml_response).returns(saml_response)
    User.any_instance.stubs(:save).returns(true)
    UserSession.any_instance.stubs(:save).returns(true)
    get :saml_login, redirect_to: '/helpdesk'
    assert_response 302
    assert_includes response.redirect_url, '/helpdesk'
  ensure
    @controller.unstub(:validate_saml_response)
    User.any_instance.unstub(:save)
    UserSession.any_instance.unstub(:save)
  end

  def test_saml_login_raises_sso_field_validation_error
    user_name = Faker::Name.name
    email = Faker::Internet.email
    redirect_url = Faker::Internet.url
    saml_response = SsoUtil::SAMLResponse.new(true, user_name, email, '', '', '', '', [], '')
    @controller.stubs(:validate_saml_response).returns(saml_response)
    @controller.stubs(:handle_sso_response).raises(SsoUtil::SsoFieldValidationError)
    User.any_instance.stubs(:save).returns(true)
    UserSession.any_instance.stubs(:save).returns(true)
    get :saml_login
    assert_response 302
    assert_includes response.redirect_url, '/login/normal'
  ensure
    @controller.unstub(:validate_saml_response)
    @controller.unstub(:handle_sso_response)
    User.any_instance.unstub(:save)
    UserSession.any_instance.unstub(:save)
  end

  def test_saml_login_with_invalid_response
    user_name = Faker::Name.name
    email = Faker::Internet.email
    saml_response = SsoUtil::SAMLResponse.new(false, user_name, email, '', '', '', '', [], '')
    @controller.stubs(:validate_saml_response).returns(saml_response)
    User.any_instance.stubs(:save).returns(true)
    UserSession.any_instance.stubs(:save).returns(true)
    get :saml_login
    assert_response 302
    assert_includes response.redirect_url, '/login/normal'
  ensure
    @controller.unstub(:validate_saml_response)
    User.any_instance.unstub(:save)
    UserSession.any_instance.unstub(:save)
  end

  def test_root_path_on_signup_complete_for_anonymous_account
    user = create_user_for_session
    User.any_instance.stubs(:active_freshid_agent?).returns(true)
    Account.any_instance.stubs(:anonymous_account?).returns(true)
    get :signup_complete, token: user.perishable_token
    assert_response 302
    assert_includes response.cookies['return_to'], '/'
  ensure
    User.any_instance.unstub(:active_freshid_agent?)
    Account.any_instance.unstub(:anonymous_account?)
  end

  def test_fetch_mobile_token_should_return_valid_mobile_jwt_token_and_reset_perishable_token
    current_account.mark_authorization_code_expiry
    user = create_user_for_session
    user.mark_perishable_token_expiry
    initial_perishable_token = user.perishable_token
    post :mobile_token, construct_params(token: initial_perishable_token)
    assert_response 200
    parsed_response = parse_response response.body
    assert_equal parsed_response['auth_token'], user.mobile_auth_token
    assert_not_equal initial_perishable_token, user.reload.perishable_token
  ensure
    reset_perishable_token_expiry(user)
    user.destroy
  end

  def test_fetch_mobile_token_should_return_bad_request_without_token
    current_account.mark_authorization_code_expiry
    post :mobile_token
    assert_response 400
  ensure
    reset_perishable_token_expiry
  end

  def test_fetch_mobile_token_should_return_bad_request_for_empty_token
    current_account.mark_authorization_code_expiry
    post :mobile_token, construct_params(token: '')
    assert_response 400
  ensure
    reset_perishable_token_expiry
  end

  def test_fetch_mobile_token_should_return_access_denied_for_invalid_token
    current_account.mark_authorization_code_expiry
    post :mobile_token, construct_params(token: Faker::Lorem.word)
    assert_response 403
  ensure
    reset_perishable_token_expiry
  end

  def test_fetch_mobile_token_should_return_bad_request_when_perishable_token_expiry_is_nil
    current_account.mark_authorization_code_expiry
    user = create_user_for_session
    initial_perishable_token = user.perishable_token
    post :mobile_token, construct_params(token: initial_perishable_token)
    assert_response 400
  ensure
    reset_perishable_token_expiry
    user.destroy
  end

  def test_fetch_mobile_token_should_return_bad_request_when_authorization_code_expiry_is_nil
    user = create_user_for_session
    user.mark_perishable_token_expiry
    initial_perishable_token = user.perishable_token
    post :mobile_token, construct_params(token: initial_perishable_token)
    assert_response 400
  ensure
    reset_perishable_token_expiry(user)
    user.destroy
  end

  def test_agent_status_change_call_to_mars
    agent = create_user_for_session
    current_account.launch :agent_statuses
    Agent.any_instance.stubs(:toggle_availability?).returns(true)
    Agent.any_instance.stubs(:available?).returns(true)
    delete :destroy, construct_params(format: 'html')
    assert_equal 1, UpdateAgentStatusAvailability.jobs.size
  ensure
    UpdateAgentStatusAvailability.jobs.clear
    Agent.any_instance.unstub(:toggle_availability?)
    Agent.any_instance.unstub(:available?)
    current_account.rollback(:agent_statuses)
  end

  def test_agent_status_change_call_to_mars_without_feature
    agent = create_user_for_session
    Agent.any_instance.stubs(:toggle_availability?).returns(true)
    Agent.any_instance.stubs(:available?).returns(true)
    Agent.any_instance.stubs(:update_attribute).returns(true)
    UpdateAgentStatusAvailability.jobs.clear
    current_account.rollback :agent_statuses
    Account.any_instance.stubs(:agent_statues_enabled?).returns(false)
    delete :destroy, construct_params(format: 'html')
    assert_equal 0, UpdateAgentStatusAvailability.jobs.size
  ensure
    Account.any_instance.unstub(:agent_statues_enabled?)
    Agent.any_instance.unstub(:toggle_availability?)
    Agent.any_instance.unstub(:available?)
    Agent.any_instance.unstub(:update_attribute)
  end

  private

    def reset_perishable_token_expiry(user = nil)
      authroization_token_key = format(AUTHORIZATION_CODE_EXPIRY, account_id: current_account.id)
      remove_others_redis_key(authroization_token_key)
      if user.present?
        perishable_token_key = format(PERISHABLE_TOKEN_EXPIRY, account_id: current_account.id, user_id: user.id)
        remove_others_redis_key(perishable_token_key)
      end
    end
end
