# frozen_string_literal: true

require_relative '../../api/test_helper'
require Rails.root.join('spec', 'support', 'user_helper.rb')

class FreshidControllerTest < ActionController::TestCase
  include UsersHelper

  def setup
    super
    Account.stubs(:current).returns(Account.first)
    User.stubs(:current).returns(User.first)
    @account = Account.current
    @user = User.current
  end

  def teardown
    Account.unstub(:current)
    User.unstub(:current)
  end

  def test_mobile_pkce_success
    org_domain = Faker::Internet.domain_name
    email = Faker::Internet.email
    Account.any_instance.stubs(:organisation_domain).returns(org_domain)
    Account.any_instance.stubs(:all_technicians).returns(@user)
    User.any_instance.stubs(:find_by_freshid_uuid).returns(@user)
    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(true)
    UserSession.any_instance.stubs(:save).returns(true)
    UserSession.any_instance.stubs(:record).returns(@user)
    @controller.request.env['HTTP_USER_AGENT'] = { /#{AppConfig['app_name']}_Native/ => 'h' }
    params_hash = { id: '12345', access_token: 'abcd', expires_in: 1000 }
    post :mobile_auth_token, controller_params(params_hash)
    parsed_response = parse_response response.body
    assert_response 200
    assert_equal parsed_response['login_status'], 'success'
    assert_equal parsed_response['token'], @user.mobile_auth_token
    assert_equal parsed_response['email'], @user.email
  ensure
    UserSession.any_instance.unstub(:record)
    UserSession.any_instance.unstub(:save)
    Account.any_instance.unstub(:freshid_org_v2_enabled?)
    Account.any_instance.unstub(:all_technicians)
    User.any_instance.unstub(:find_by_freshid_uuid)
    Account.any_instance.unstub(:organisation_domain)
  end

  def test_mobile_pkce_failure_due_to_session_creation
    org_domain = Faker::Internet.domain_name
    email = Faker::Internet.email
    Account.any_instance.stubs(:organisation_domain).returns(org_domain)
    Account.any_instance.stubs(:all_technicians).returns(@user)
    User.any_instance.stubs(:find_by_freshid_uuid).returns(@user)
    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(true)
    UserSession.any_instance.stubs(:save).returns(false)
    @controller.request.env['HTTP_USER_AGENT'] = { /#{AppConfig['app_name']}_Native/ => 'h' }
    params_hash = { id: '12345', access_token: 'abcd', expires_in: 1000 }
    post :mobile_auth_token, controller_params(params_hash)
    parsed_response = parse_response response.body
    assert_response 400
    assert_equal parsed_response['login_status'], 'failed'
    assert_equal parsed_response['message'], 'Session creation failed'
  ensure
    UserSession.any_instance.unstub(:save)
    Account.any_instance.unstub(:freshid_org_v2_enabled?)
    User.any_instance.unstub(:find_by_freshid_uuid)
    Account.any_instance.unstub(:all_technicians)
    Account.any_instance.unstub(:organisation_domain)
  end

  def test_mobile_pkce_failure_with_invalid_parameters
    params_hash = { sample: '123' }
    post :mobile_auth_token, controller_params(params_hash)
    parsed_response = parse_response response.body
    assert_response 400
    assert_equal parsed_response['login_status'], 'failed'
    assert_equal parsed_response['message'], 'Invalid parameters'
  end

  def test_mobile_pkce_failure_with_user_not_found
    org_domain = Faker::Internet.domain_name
    email = Faker::Internet.email
    Account.any_instance.stubs(:organisation_domain).returns(org_domain)
    Account.any_instance.stubs(:all_technicians).returns(@user)
    User.any_instance.stubs(:find_by_freshid_uuid).returns(nil)
    params_hash = { id: '12345', access_token: 'abcd', expires_in: 1000 }
    post :mobile_auth_token, controller_params(params_hash)
    parsed_response = parse_response response.body
    assert_response 400
    assert_equal parsed_response['login_status'], 'failed'
    assert_equal parsed_response['message'], 'User not found'
  ensure
    User.any_instance.unstub(:find_by_freshid_uuid)
    Account.any_instance.unstub(:all_technicians)
    Account.any_instance.unstub(:organisation_domain)
  end
end
