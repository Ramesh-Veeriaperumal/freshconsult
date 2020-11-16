# frozen_string_literal: true

require_relative '../../../api/api_test_helper'
['user_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
class FreshidControllerFlowNewTest < ActionDispatch::IntegrationTest
  include UsersHelper

  def setup
    super
    reset_request_headers
  end

  def test_authorize_callback_when_user_doesnt_exist
    # When freshid LoginUtil returns nil, as freshid is not able to authenticate user
    @account.launch(:freshid_org_v2)
    org_domain = Faker::Internet.domain_name
    Account.any_instance.stubs(:organisation_domain).returns(org_domain)
    Freshid::V2::LoginUtil.stubs(:fetch_user_by_code).returns(nil)
    params = { error: 'login_required', error_description: 'user_login_is_required' }
    get '/freshid/authorize_callback', params
    assert_equal I18n.t(FreshidController::FLASH_USER_NOT_EXIST), session[:flash_message]
    assert_response 302
  ensure
    Account.any_instance.unstub(:organisation_domain)
    Freshid::V2::LoginUtil.unstub(:fetch_user_by_code)
  end

  def test_authorize_callback_when_user_is_invalid
    # When the agent is deleted
    agent = add_agent(@account, active: true)
    @account.launch(:freshid_org_v2)
    org_domain = Faker::Internet.domain_name
    Account.any_instance.stubs(:organisation_domain).returns(org_domain)
    Freshid::V2::LoginUtil.stubs(:fetch_user_by_code).returns(auth_params(agent))
    agent.deleted = true
    agent.save
    get '/freshid/authorize_callback', call_params
    assert_equal I18n.t(FreshidController::FLASH_INVALID_USER), session[:flash_message]
    assert_response 302
  ensure
    Account.any_instance.unstub(:organisation_domain)
    Freshid::V2::LoginUtil.unstub(:fetch_user_by_code)
  end

  def test_authorize_callback_when_user_is_valid
    # success case
    agent = add_agent(@account, active: true)
    @account.launch(:freshid_org_v2)
    org_domain = Faker::Internet.domain_name
    freshid_authorization = agent.authorizations.build(provider: Freshid::Constants::FRESHID_PROVIDER, uid: SecureRandom.uuid)
    User.any_instance.stubs(:freshid_authorization).returns(freshid_authorization)
    Account.any_instance.stubs(:organisation_domain).returns(org_domain)
    auth_parameters = auth_params(agent)
    Freshid::V2::LoginUtil.stubs(:fetch_user_by_code).returns(auth_parameters)
    get '/freshid/authorize_callback', call_params
    assert_equal auth_parameters[:refresh_token], User.last.freshid_authorization.refresh_token
    assert_equal auth_parameters[:access_token], User.last.freshid_authorization.access_token
    assert_response 302
  ensure
    User.any_instance.unstub(:freshid_authorization)
    Account.any_instance.unstub(:organisation_domain)
    Freshid::V2::LoginUtil.unstub(:fetch_user_by_code)
  end

  def test_authorize_callback_when_user_doesnt_exist_mobile_login
    # When Freshid::V2::LoginUtil returns nil (agent logs in via mobile)
    @account.launch(:freshid_org_v2)
    org_domain = Faker::Internet.domain_name
    Account.any_instance.stubs(:organisation_domain).returns(org_domain)
    Freshid::V2::LoginUtil.stubs(:fetch_user_by_code).returns(nil)
    params = { error: 'login_required', error_description: 'user_login_is_required', mobile_login: true }
    get '/freshid/authorize_callback', params
    assert_equal true, response.body.include?('mobile_login')
    assert_response 302
  ensure
    Account.any_instance.unstub(:organisation_domain)
    Freshid::V2::LoginUtil.unstub(:fetch_user_by_code)
  end

  def test_authorize_callback_when_user_present_in_mobile_login
    # When Freshid::V2::LoginUtil returns agent who logs in via mobile, (success case)
    agent = add_agent(@account, active: true)
    @account.launch(:freshid_org_v2)
    org_domain = Faker::Internet.domain_name
    freshid_authorization = agent.authorizations.build(provider: Freshid::Constants::FRESHID_PROVIDER, uid: SecureRandom.uuid)
    User.any_instance.stubs(:freshid_authorization).returns(freshid_authorization)
    Account.any_instance.stubs(:organisation_domain).returns(org_domain)
    Freshid::V2::LoginUtil.stubs(:fetch_user_by_code).returns(auth_params(agent))
    get '/freshid/authorize_callback', call_params.merge!(mobile_login: true)
    assert_response 302
  ensure
    User.any_instance.unstub(:freshid_authorization)
    Account.any_instance.unstub(:organisation_domain)
    Freshid::V2::LoginUtil.unstub(:fetch_user_by_code)
  end

  def test_authorize_callback_when_mobile_login_failed
    # When login failed as user session could not be saved
    agent = add_agent(@account, active: true)
    @account.launch(:freshid_org_v2)
    org_domain = Faker::Internet.domain_name
    freshid_authorization = agent.authorizations.build(provider: Freshid::Constants::FRESHID_PROVIDER, uid: SecureRandom.uuid)
    User.any_instance.stubs(:freshid_authorization).returns(freshid_authorization)
    Account.any_instance.stubs(:organisation_domain).returns(org_domain)
    UserSession.any_instance.stubs(:save).returns(false)
    Freshid::V2::LoginUtil.stubs(:fetch_user_by_code).returns(auth_params(agent))
    get '/freshid/authorize_callback', call_params.merge!(mobile_login: true)
    assert_response 302
  ensure
    User.any_instance.unstub(:freshid_authorization)
    UserSession.any_instance.unstub(:save)
    Account.any_instance.unstub(:organisation_domain)
    Freshid::V2::LoginUtil.unstub(:fetch_user_by_code)
  end

  def test_authorize_callback_when_feature_not_exist
    # When freshid_org_v2 feature isnt enabled.
    agent = add_agent(@account, active: true)
    @account.rollback(:freshid_org_v2)
    FreshidController.any_instance.stubs(:fetch_user_by_code).returns(agent)
    get '/freshid/authorize_callback', call_params
    assert_response 302
  ensure
    FreshidController.any_instance.unstub(:fetch_user_by_code)
  end

  def test_customer_authorize_callback
    # When none of the features are enabled.
    user = add_new_user(@account, active: true)
    @account.rollback(:freshid_sso_sync)
    @account.rollback(:freshid_org_v2)
    FreshidController.any_instance.stubs(:fetch_freshid_end_user_by_code).returns(freshid_user_params(user))
    get '/freshid/customer_authorize_callback', call_params
    assert_response 302
  ensure
    FreshidController.any_instance.unstub(:fetch_freshid_end_user_by_code)
  end

  def test_customer_authorize_callback_when_freshid_org_v2_enabled
    # When only freshid is enabled
    user = add_new_user(@account, active: true)
    @account.rollback(:freshid_sso_sync)
    @account.launch(:freshid_org_v2)
    FreshidController.any_instance.stubs(:fetch_freshid_end_user_by_code).returns(freshid_user_params(user))
    get '/freshid/customer_authorize_callback', call_params
    assert_response 302
  ensure
    FreshidController.any_instance.unstub(:fetch_freshid_end_user_by_code)
  end

  def test_customer_authorize_callback_without_id_token
    # When all features are enabled , but there was error decoding token
    @account.launch(:freshid_sso_sync)
    @account.launch(:freshid_org_v2)
    JWT.stubs(:decode).returns({})
    Account.any_instance.stubs(:contact_custom_sso_enabled?).returns(true)
    get '/freshid/customer_authorize_callback', call_params
    assert_equal I18n.t(FreshidController::FLASH_USER_NOT_EXIST), session[:flash_message]
    assert_response 302
  ensure
    JWT.unstub(:decode)
    Account.any_instance.unstub(:contact_custom_sso_enabled?)
  end

  def test_customer_authorize_callback_with_id_token
    # When all features are enabled , the token was decoded successfully
    user = add_new_user(@account, active: true)
    @account.launch(:freshid_sso_sync)
    @account.launch(:freshid_org_v2)
    payload = { email: user.email }
    token = JWT.encode payload, nil, 'none'
    Freshid::V2::LoginUtil.stubs(:fetch_contact_token_by_code).returns(token)
    Account.any_instance.stubs(:contact_custom_sso_enabled?).returns(true)
    get '/freshid/customer_authorize_callback', call_params
    assert_response 302
  ensure
    Freshid::V2::LoginUtil.unstub(:fetch_contact_token_by_code)
    Account.any_instance.unstub(:contact_custom_sso_enabled?)
  end

  private

    def auth_params(user)
      {
        user: user,
        access_token: '123456787645',
        refresh_token: 'samplerefreshtoken147392',
        access_token_expires_in: Time.now.to_i + 300
      }
    end

    def freshid_user_params(user)
      {
        email: user.email,
        uuid: '814817c5-a2a4-0b7c-c202-f192b0e57d09',
        first_name: user.name,
        status: 'ACTIVATED'
      }
    end

    def call_params
      { code: '12345678', session_token: 'sessiondummycode3456', session_state: '23bsamplestate34567' }
    end
end
