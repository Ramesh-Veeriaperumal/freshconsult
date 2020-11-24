# frozen_string_literal:true

require_relative '../../../api/api_test_helper'
['user_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }

class Support::LoginControllerFlowTest < ActionDispatch::IntegrationTest
  include UsersHelper

  def test_support_login_when_session_timed_out_for_customer
    user_params = { name: Faker::Name.name, email: Faker::Internet.email, helpdesk_agent: 0 }
    user = add_new_user(@account, user_params)
    user.password = 'test'
    user.save
    user.make_current
    @account.launch(:idle_session_timeout)
    @account.account_additional_settings_from_cache.additional_settings[:idle_session_timeout] = 5
    @account.save
    Support::LoginController.any_instance.stubs(:session_timeout_allowed?).returns(true)
    UserSession.any_instance.stubs(:record).returns(user)
    post '/support/login', user_session: { email: user.email, password: 'test', remember_me: '0' }
    sleep 6
    post '/support/login', user_session: { email: user.email, password: 'test', remember_me: '0' }
    assert_equal I18n.t(:'flash.general.need_login'), flash[:notice]
  ensure
    Support::LoginController.any_instance.unstub(:session_timeout_allowed?)
    UserSession.any_instance.unstub(:record)
  end

  def test_login_new
    User.reset_current_user
    reset_request_headers
    get '/support/login/new'
    assert_response 200
    assert_template('new')
  end

  def test_new_login_freshid_agent
    user = add_agent(@account, active: true)
    reset_request_headers
    @account.launch(:freshid)
    Support::LoginControllerFlowTest.any_instance.stubs(:old_ui?).returns(true)
    set_request_auth_headers(user)
    User.any_instance.stubs(:active_freshid_agent?).returns(true)
    get "/support/login?new_account_signup=true&signup_email=#{user.email}"
    login_msg = Addressable::URI.encode_component(I18n.t('support.login.freshid_login_message'))
    expected_login_message = "login_message=#{login_msg}"
    assert_equal true, response.body.include?(expected_login_message)
    assert_response 302
  ensure
    Support::LoginControllerFlowTest.any_instance.unstub(:old_ui?)
    User.any_instance.unstub(:active_freshid_agent?)
  end

  def test_new_login_when_freshid_sso_sync_enabled
    @account.launch(:freshid_sso_sync)
    Account.any_instance.stubs(:freshdesk_sso_enabled?).returns(true)
    Account.any_instance.stubs(:sso_options).returns(HashWithIndifferentAccess.new(sso_type: 'simple', login_url: 'https://abc.com'))
    get '/support/login/new'
    assert_response 302
    assert_redirected_to "https://abc.com?host_url=#{request.host}"
  ensure
    Account.any_instance.unstub(:freshdesk_sso_enabled?)
    Account.any_instance.unstub(:sso_options)
  end

  def test_new_login_when_freshid_sso_sync_disabled
    @account.rollback(:freshid_sso_sync)
    Account.any_instance.stubs(:freshdesk_sso_enabled?).returns(true)
    Account.any_instance.stubs(:sso_options).returns(HashWithIndifferentAccess.new(sso_type: 'simple', login_url: 'https://abc.com'))
    get '/support/login/new'
    assert_response 302
    assert_redirected_to "https://abc.com?host_url=#{request.host}"
  ensure
    Account.any_instance.unstub(:freshdesk_sso_enabled?)
    Account.any_instance.unstub(:sso_options)
  end

  def test_create
    user = add_agent_and_set_password
    reset_request_headers
    params = signup_params(user.email).merge!('g-recaptcha-response' => '')
    post '/support/login', params
    assert_response 302
    assert response.headers['Set-Cookie'].include?('helpdesk_url=')
  end

  def test_login_for_non_user
    user = add_agent_and_set_password
    user.destroy
    reset_request_headers
    post '/support/login', signup_params(user.email)
    assert_response 200
    assert_equal false, response.headers['Set-Cookie'].include?('helpdesk_url=')
  end

  def test_create_for_freshid_agent
    user = add_agent_and_set_password
    reset_request_headers
    Support::LoginController.stubs(:freshid_agent?).returns(true)
    post '/support/login', signup_params(user.email)
    assert_response 302
  ensure
    Support::LoginController.unstub(:freshid_agent?)
  end

  def test_create_for_deleted_agent
    user = add_agent(@account, active: true)
    user.password = 'test'
    user.deleted = true
    user.save
    reset_request_headers
    post '/support/login', signup_params(user.email)
    assert_response 200
    assert_equal true, response.body.include?(I18n.t('activerecord.errors.messages.contact_admin'))
  end

  def test_create_verify_captcha_is_false
    user = add_agent_and_set_password
    reset_request_headers
    Support::LoginController.any_instance.stubs(:verify_recaptcha).returns(false)
    params = signup_params(user.email).merge!('g-recaptcha-response' => '')
    post '/support/login', params
    assert_response 200
    assert_equal true, response.body.include?(I18n.t('captcha_verify_message'))
  ensure
    Support::LoginController.any_instance.unstub(:verify_recaptcha)
  end

  def test_create_where_user_session_cannot_be_saved
    user = add_agent_and_set_password
    reset_request_headers
    UserSession.any_instance.stubs(:save).returns(false)
    params = signup_params(user.email).merge!('g-recaptcha-response' => '')
    post '/support/login', params
    assert_response 200
    assert_equal false, response.body.include?(I18n.t('captcha_verify_message'))
  ensure
    UserSession.any_instance.unstub(:save)
  end

  def test_create_no_ssl_redirection_error
    user = add_agent_and_set_password
    reset_request_headers
    params = { user_session: { email: user.email, password: 'test', remember_me: '0' } }
    post '/support/login', signup_params(user.email)
    Portal.any_instance.stubs(:portal_url).returns('localhost.freshpo.com')
    @account.make_current
    @account.reload
    session_params = { 'rack.session' => { 'return_to' => '/subscription/billing' }, 'HTTP_REFERER' => 'http://localhost.freshpo.com' }
    get '/support/login/new', nil, session_params
    assert_response 200
    assert_equal true, response.body.include?(I18n.t('no_ssl_redirection'))
  ensure
    Portal.any_instance.unstub(:portal_url)
  end

  def test_create_for_stale_user_record
    user = add_agent(@account, active: true)
    user.password = 'test'
    user.password_expired = true
    user.save
    perishable_token_before = user.perishable_token
    reset_request_headers
    UserSession.any_instance.stubs(:stale_record).returns(user)
    params = signup_params(user.email)
    post '/support/login', params
    user.reload
    assert_response 302
    assert_not_equal perishable_token_before, user.perishable_token
  ensure
    UserSession.any_instance.unstub(:stale_record)
  end

  private

    def signup_params(user_email)
      { user_session: { email: user_email, password: 'test', remember_me: '0' } }
    end

    def add_agent_and_set_password
      user = add_agent(@account, active: true)
      user.password = 'test'
      user.save
      user
    end
end
