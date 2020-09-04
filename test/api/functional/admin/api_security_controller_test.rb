# frozen_string_literal: true

require_relative '../../test_helper'
require Rails.root.join('test', 'api', 'helpers', 'admin', 'api_security_helper.rb')

class Admin::ApiSecurityControllerTest < ActionController::TestCase
  include Admin::ApiSecurityHelper
  def test_whitelisted_ips_not_enabled
    Account.any_instance.stubs(:whitelisted_ips_enabled?).returns(false)
    get :show, controller_params
    assert_response 200
    assert_nil JSON.parse(response.body)['whitelisted_ips']
  ensure
    Account.any_instance.unstub(:whitelisted_ips_enabled?)
  end

  def test_whitelisted_ip_enabled
    Account.any_instance.stubs(:whitelisted_ips_enabled?).returns(true)
    Account.current.stubs(:whitelisted_ip).returns(nil)
    get :show, controller_params
    assert_response 200
    assert_equal whitelisted_ip_not_configured, JSON.parse(response.body)['whitelisted_ips']
  ensure
    Account.any_instance.unstub(:whitelisted_ips_enabled?)
  end

  def test_help_widget_not_enabled
    Account.any_instance.stubs(:help_widget_enabled?).returns(false)
    get :show, controller_params
    assert_response 200
    assert_nil JSON.parse(response.body)['help_widget']
  ensure
    Account.any_instance.unstub(:help_widget_enabled?)
  end

  def test_custom_password_policy_not_enabled
    Account.any_instance.stubs(:custom_password_policy_enabled?).returns(false)
    get :show, controller_params
    assert_response 200
    assert_nil JSON.parse(response.body)['agent_password_policy']
    assert_nil JSON.parse(response.body)['contact_password_policy']
  ensure
    Account.any_instance.unstub(:custom_password_policy_enabled?)
  end

  def test_password_policy_with_freshid_integration_enabled
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(true)
    get :show, controller_params
    assert_response 200
    assert_nil JSON.parse(response.body)['agent_password_policy']
    assert_equal password_policy.stringify_keys, JSON.parse(response.body)['contact_password_policy']
  ensure
    Account.any_instance.unstub(:custom_password_policy_enabled?)
  end

  def test_account_current_ip
    get :show, controller_params
    assert_response 200
    assert_equal request.remote_ip, response.api_meta[:current_ip]
  end

  def test_account_current_ip_when_whitelisted_ip_disabled
    Account.any_instance.stubs(:whitelisted_ips_enabled?).returns(false)
    get :show, controller_params
    assert_response 200
    assert_nil response.api_meta[:current_ip]
  ensure
    Account.any_instance.unstub(:whitelisted_ips_enabled?)
  end

  def test_account_freshid_migration_not_in_process
    get :show, controller_params(version: 'private')
    assert_response 200
    assert_equal false, response.api_meta[:freshid_migration_in_progress]
  end

  def test_account_freshid_migration_in_process
    Account.current.stubs(:freshid_migration_in_progress?).returns(true)
    get :show, controller_params(version: 'private')
    assert_response 200
    assert_equal true, response.api_meta[:freshid_migration_in_progress]
  ensure
    Account.current.unstub(:freshid_migration_in_progress)
  end

  def test_security_index_public_api
    stub_account
    CustomRequestStore.stubs(:read).with(:private_api_request).returns(false)
    get :show, controller_params(version: 'v2')
    assert_response 200
    match_json(security_index_api_response_pattern)
  ensure
    unstub_account
    CustomRequestStore.unstub(:read)
  end

  def test_security_index_private_api
    stub_account
    get :show, controller_params(version: 'private')
    assert_response 200
    match_json(security_index_api_response_pattern)
  ensure
    unstub_account
  end

  private

    def stub_account
      Account.current.stubs(:whitelisted_ips_enabled?).returns(true)
      Account.current.stubs(:help_widget_enabled?).returns(true)
      Account.current.stubs(:notification_emails).returns(notification_emails)
      Account.current.stubs(:freshid_integration_enabled?).returns(false)
      create_whitelisted_ip(whitelisted_ip)
      create_password_policy(agent_password_policy)
    end

    def unstub_account
      Account.current.unstub(:whitelisted_ips_enabled?)
      Account.any_instance.unstub(:help_widget_enabled?)
      Account.current.unstub(:notification_emails)
      Account.current.unstub(:freshid_integration_enabled?)
      destroy_password_policy
      destroy_whitelisted_ip
    end

    def create_whitelisted_ip(whitelisted_ip)
      Account.current.whitelisted_ip_attributes = whitelisted_ip
      whitelisted_ips = @account.whitelisted_ip
      whitelisted_ips.load_ip_info(User.current.current_login_ip)
    end

    def create_password_policy(password_policy)
      Account.current.agent_password_policy = PasswordPolicy.new(password_policy)
    end

    def destroy_whitelisted_ip
      Account.current.whitelisted_ip.destroy
    end

    def destroy_password_policy
      Account.current.agent_password_policy.destroy
    end
end
