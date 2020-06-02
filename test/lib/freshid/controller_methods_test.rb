require_relative '../test_helper'
require 'minitest/spec'

class ControllerMethodsTest < ActiveSupport::TestCase
  def setup
    super
    @test_obj = Object.new
    @test_obj.extend(Freshid::ControllerMethods)
    @user = create_test_account
    @account = @user.account.make_current
    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(true)
  end

  def teardown
    Account.any_instance.unstub(:freshid_org_v2_enabled?)
  end

  def test_customer_login_url
    Account.any_instance.stubs(:freshid_sso_sync_enabled?).returns(true)
    Account.any_instance.stubs(:freshid_custom_policy_enabled?).returns(true)
    @test_obj.class.module_eval { attr_accessor :current_account, :freshid_customer_authorize_callback_url }
    @test_obj.current_account = @account
    @test_obj.freshid_customer_authorize_callback_url = 'test_callback_url'
    freshid_custom_policy_config = {
      contact: {
        entrypoint_url: 'https://loginurl/loginpage',
        entrypoint_id: '181734727304930011',
        entrypoint_title: 'Custom Policy Contact',
        logout_redirect_url: 'logout_url'
      }
    }
    @account.account_additional_settings.enable_freshid_custom_policy(freshid_custom_policy_config)
    assert_equal "https://loginurl/loginpage?client_id=#{FRESHID_V2_CLIENT_ID}&redirect_uri=test_callback_url", @test_obj.customer_login_url
  ensure
    Account.any_instance.unstub(:freshid_sso_sync_enabled?)
  end
end
