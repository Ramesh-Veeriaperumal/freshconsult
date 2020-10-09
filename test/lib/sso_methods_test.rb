require_relative '../api/unit_test_helper'
require 'webmock/minitest'
class SsoMethodsTest < ActionView::TestCase
  def setup
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:save).returns(true)
    Account.any_instance.stubs(:save!).returns(true)
    @account = Account.first
    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(true)
  end

  def teardown
    Account.unstub(:current)
    Account.any_instance.unstub(:save)
    Account.any_instance.unstub(:save!)
    Account.any_instance.unstub(:freshid_org_v2_enabled?)
    super
  end

  def basic_sso_hash
    { 'login_url' => '', 'logout_url' => '', 'sso_type' => '' }
  end

  def test_allow_sso_login
    Account.any_instance.stubs(:launched?).returns(true)
    sso = @account.allow_sso_login?
    assert_equal true, sso
  ensure
    Account.any_instance.unstub(:launched?)
  end

  def test_reset_sso_options
    sso = @account.reset_sso_options
    assert_equal basic_sso_hash, sso
  end

  def test_oauth2_sso_enabled
    Account.any_instance.stubs(:sso_options).returns(nil)
    sso = @account.oauth2_sso_enabled?
    assert_equal false, sso
  ensure
    Account.any_instance.unstub(:sso_options)
  end

  def test_is_saml_sso
    Account.any_instance.stubs(:sso_options).returns({})
    sso = @account.is_saml_sso?
    assert_equal false, sso
  ensure
    Account.any_instance.unstub(:sso_options)
  end

  def test_enable_agent_oauth2_sso
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    Account.any_instance.stubs(:add_feature).returns(true)
    Account.any_instance.stubs(:customer_oauth2_sso_enabled?).returns(false)
    sso = @account.enable_agent_oauth2_sso!('test url')
    assert_equal true, sso
  ensure
    Account.any_instance.unstub(:freshid_enabled?)
    Account.any_instance.unstub(:add_feature)
    Account.any_instance.unstub(:customer_oauth2_sso_enabled?)
  end

  def test_enable_agent_oauth2_sso_without_sso_sync
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    Account.any_instance.stubs(:add_feature).returns(true)
    Account.any_instance.stubs(:customer_oauth2_sso_enabled?).returns(false)
    Account.any_instance.stubs(:freshid_sso_sync_enabled?).returns(false)
    sso = @account.enable_agent_oauth2_sso!('test url')
    assert_equal true, sso
  ensure
    Account.any_instance.unstub(:freshid_enabled?)
    Account.any_instance.unstub(:add_feature)
    Account.any_instance.unstub(:customer_oauth2_sso_enabled?)
    Account.any_instance.unstub(:freshid_sso_sync_enabled?)
  end

  def test_disable_agent_oauth2_sso
    Account.any_instance.stubs(:agent_oauth2_sso_enabled?).returns(true)
    Account.any_instance.stubs(:sso_options).returns(agent_oauth2: 'oauth2', agent_oauth2_config: 'oauth2_config', sso_type: 'type')
    Account.any_instance.stubs(:customer_oauth2_sso_enabled?).returns(false)
    Account.any_instance.stubs(:reset_feature).returns(true)
    sso = @account.disable_agent_oauth2_sso!
    assert_equal true, sso
  ensure
    Account.any_instance.unstub(:agent_oauth2_sso_enabled?)
    Account.any_instance.unstub(:sso_options)
    Account.any_instance.unstub(:customer_oauth2_sso_enabled?)
    Account.any_instance.unstub(:reset_feature)
  end

  def test_enable_customer_oauth2_sso
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    Account.any_instance.stubs(:add_feature).returns(true)
    Account.any_instance.stubs(:agent_oauth2_sso_enabled?).returns(false)
    sso = @account.enable_customer_oauth2_sso!('test url')
    assert_equal true, sso
  ensure
    Account.any_instance.unstub(:freshid_enabled?)
    Account.any_instance.unstub(:add_feature)
    Account.any_instance.unstub(:agent_oauth2_sso_enabled?)
  end

  def test_enable_customer_oauth2_sso_without_sso_sync
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    Account.any_instance.stubs(:add_feature).returns(true)
    Account.any_instance.stubs(:agent_oauth2_sso_enabled?).returns(false)
    Account.any_instance.stubs(:freshid_sso_sync_enabled?).returns(false)
    sso = @account.enable_customer_oauth2_sso!('test url')
    assert_equal true, sso
  ensure
    Account.any_instance.unstub(:freshid_enabled?)
    Account.any_instance.unstub(:add_feature)
    Account.any_instance.unstub(:agent_oauth2_sso_enabled?)
    Account.any_instance.unstub(:freshid_sso_sync_enabled?)
  end

  def test_disable_customer_oauth2_sso
    Account.any_instance.stubs(:customer_oauth2_sso_enabled?).returns(true)
    Account.any_instance.stubs(:sso_options).returns(customer_oauth2: 'oauth2', customer_oauth2_config: 'oauth2_config', sso_type: 'type')
    Account.any_instance.stubs(:reset_feature).returns(true)
    Account.any_instance.stubs(:agent_oauth2_sso_enabled?).returns(false)
    sso = @account.disable_customer_oauth2_sso!
    assert_equal true, sso
  ensure
    Account.any_instance.unstub(:customer_oauth2_sso_enabled?)
    Account.any_instance.unstub(:sso_options)
    Account.any_instance.unstub(:reset_feature)
    Account.any_instance.unstub(:agent_oauth2_sso_enabled?)
  end

  def test_remove_oauth2_sso_options
    Account.any_instance.stubs(:revoke_feature).returns(true)
    Account.any_instance.stubs(:sso_options).returns(nil)
    sso = @account.remove_oauth2_sso_options
    assert_equal nil, sso
  ensure
    Account.any_instance.unstub(:revoke_feature)
    Account.any_instance.unstub(:sso_options)
  end

  def test_agent_oauth2_logout_redirect_url
    Account.any_instance.stubs(:agent_oauth2_sso_enabled?).returns(false)
    sso = @account.agent_oauth2_logout_redirect_url
    assert_equal nil, sso
  ensure
    Account.any_instance.unstub(:agent_oauth2_sso_enabled?)
  end

  def test_customer_oauth2_logout_redirect_url
    Account.any_instance.stubs(:customer_oauth2_sso_enabled?).returns(false)
    sso = @account.customer_oauth2_logout_redirect_url
    assert_equal nil, sso
  ensure
    Account.any_instance.unstub(:customer_oauth2_sso_enabled?)
  end

  def test_freshid_saml_sso_enabled
    Account.any_instance.stubs(:sso_options).returns(nil)
    sso = @account.freshid_saml_sso_enabled?
    assert_equal false, sso
  ensure
    Account.any_instance.unstub(:sso_options)
  end

  def test_freshid_sso_enabled
    Account.any_instance.stubs(:sso_options).returns(nil)
    sso = @account.freshid_sso_enabled?
    assert_equal false, sso
  ensure
    Account.any_instance.unstub(:sso_options)
  end

  def test_enable_agent_freshid_saml_sso
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    Account.any_instance.stubs(:add_feature).returns(true)
    Account.any_instance.stubs(:customer_freshid_saml_sso_enabled?).returns(false)
    sso = @account.enable_agent_freshid_saml_sso!('test_url')
    assert_equal true, sso
  ensure
    Account.any_instance.unstub(:freshid_enabled?)
    Account.any_instance.unstub(:add_feature)
    Account.any_instance.unstub(:customer_freshid_saml_sso_enabled?)
  end

  def test_enable_agent_freshid_saml_sso_without_sso_sync
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    Account.any_instance.stubs(:add_feature).returns(true)
    Account.any_instance.stubs(:customer_freshid_saml_sso_enabled?).returns(false)
    Account.any_instance.stubs(:freshid_sso_sync_enabled?).returns(false)
    sso = @account.enable_agent_freshid_saml_sso!('test_url')
    assert_equal true, sso
  ensure
    Account.any_instance.unstub(:freshid_enabled?)
    Account.any_instance.unstub(:add_feature)
    Account.any_instance.unstub(:customer_freshid_saml_sso_enabled?)
    Account.any_instance.unstub(:freshid_sso_sync_enabled?)
  end

  def test_enable_customer_freshid_saml_sso
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    Account.any_instance.stubs(:add_feature).returns(true)
    Account.any_instance.stubs(:agent_freshid_saml_sso_enabled?).returns(false)
    Account.any_instance.stubs(:freshid_sso_sync_enabled?).returns(false)
    sso = @account.enable_customer_freshid_saml_sso!('test_url')
    assert_equal true, sso
  ensure
    Account.any_instance.unstub(:freshid_enabled?)
    Account.any_instance.unstub(:add_feature)
    Account.any_instance.unstub(:agent_freshid_saml_sso_enabled?)
    Account.any_instance.unstub(:freshid_sso_sync_enabled?)
  end

  def test_enable_customer_freshid_saml_sso_without_sso_sync
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    Account.any_instance.stubs(:add_feature).returns(true)
    Account.any_instance.stubs(:agent_freshid_saml_sso_enabled?).returns(false)
    sso = @account.enable_customer_freshid_saml_sso!('test_url')
    assert_equal true, sso
  ensure
    Account.any_instance.unstub(:freshid_enabled?)
    Account.any_instance.unstub(:add_feature)
    Account.any_instance.unstub(:agent_freshid_saml_sso_enabled?)
  end

  def test_disable_agent_freshid_saml_sso
    @account.enable_agent_freshid_saml_sso!('test_url')
    Account.any_instance.stubs(:reset_feature).returns(true)
    sso = @account.disable_agent_freshid_saml_sso!
    assert_equal true, sso
    assert_equal false, @account.sso_enabled
  ensure
    Account.any_instance.unstub(:reset_feature)
  end

  def test_disable_customer_freshid_saml_sso
    Account.any_instance.stubs(:customer_freshid_saml_sso_enabled?).returns(true)
    Account.any_instance.stubs(:sso_options).returns(customer_freshid_saml: 'customer saml', customer_freshid_saml_config: 'saml config', sso_type: 'type')
    Account.any_instance.stubs(:agent_freshid_saml_sso_enabled?).returns(false)
    Account.any_instance.stubs(:reset_feature).returns(true)
    sso = @account.disable_customer_freshid_saml_sso!
    assert_equal true, sso
  ensure
    Account.any_instance.unstub(:customer_freshid_saml_sso_enabled?)
    Account.any_instance.unstub(:sso_options)
    Account.any_instance.unstub(:agent_freshid_saml_sso_enabled?)
    Account.any_instance.unstub(:reset_feature)
  end

  def test_remove_freshid_saml_sso_options
    Account.any_instance.stubs(:revoke_feature).returns(true)
    Account.any_instance.stubs(:sso_options).returns(nil)
    sso = @account.remove_freshid_saml_sso_options
    assert_equal nil, sso
  ensure
    Account.any_instance.unstub(:revoke_feature)
    Account.any_instance.unstub(:sso_options)
  end

  def test_agent_freshid_saml_logout_redirect_url
    Account.any_instance.stubs(:agent_freshid_saml_sso_enabled?).returns(false)
    sso = @account.agent_freshid_saml_logout_redirect_url
    assert_equal nil, sso
  ensure
    Account.any_instance.unstub(:agent_freshid_saml_sso_enabled?)
  end

  def test_customer_freshid_saml_logout_redirect_url
    Account.any_instance.stubs(:customer_freshid_saml_sso_enabled?).returns(false)
    sso = @account.customer_freshid_saml_logout_redirect_url
    assert_equal nil, sso
  ensure
    Account.any_instance.unstub(:customer_freshid_saml_sso_enabled?)
  end

  def test_sso_login_url_with_saml
    Account.any_instance.stubs(:is_saml_sso?).returns(true)
    Account.any_instance.stubs(:sso_options).returns(saml_login_url: 'login_url')
    sso = @account.sso_login_url
    assert_equal 'login_url', sso
  ensure
    Account.any_instance.unstub(:is_saml_sso?)
    Account.any_instance.unstub(:sso_options)
  end

  def test_sso_login_url_without_saml
    Account.any_instance.stubs(:is_saml_sso?).returns(false)
    Account.any_instance.stubs(:sso_options).returns(login_url: 'login_url')
    sso = @account.sso_login_url
    assert_equal 'login_url', sso
  ensure
    Account.any_instance.unstub(:is_saml_sso?)
    Account.any_instance.unstub(:sso_options)
  end

  def test_sso_logout_url_with_saml
    Account.any_instance.stubs(:is_saml_sso?).returns(true)
    Account.any_instance.stubs(:sso_options).returns(saml_logout_url: 'logout_url')
    sso = @account.sso_logout_url
    assert_equal 'logout_url', sso
  ensure
    Account.any_instance.unstub(:is_saml_sso?)
    Account.any_instance.unstub(:sso_options)
  end

  def test_sso_logout_url_without_saml
    Account.any_instance.stubs(:is_saml_sso?).returns(false)
    Account.any_instance.stubs(:sso_options).returns(logout_url: 'logout_url')
    sso = @account.sso_logout_url
    assert_equal 'logout_url', sso
  ensure
    Account.any_instance.unstub(:is_saml_sso?)
    Account.any_instance.unstub(:sso_options)
  end

  def test_enable_agent_custom_sso
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    Account.any_instance.stubs(:add_feature).returns(true)
    sso = @account.enable_agent_custom_sso!({entrypoint_url: 'some_login_link'})
    assert_equal true, sso
  ensure
    Account.any_instance.unstub(:freshid_enabled?)
    Account.any_instance.unstub(:add_feature)
  end

  def test_enable_agent_custom_sso_with_freshid_disabled
    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(false)
    Account.any_instance.stubs(:add_feature).returns(true)
    @account.enable_contact_custom_sso!(entrypoint_url: 'some_login_link')
    assert_equal false, @account.sso_enabled
  ensure
    Account.any_instance.unstub(:freshid_org_v2_enabled?)
    Account.any_instance.unstub(:add_feature)
  end

  def test_enable_contact_custom_sso_without_freshid_disabled
    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(false)
    mock = Minitest::Mock.new
    mock.expect(:call, true, ['FRESHID CUSTOM POLICY :: SSO METHODS ::  Enable Contact Custom SSO :: Freshid not enabled'])
    Rails.logger.stub :info, mock do
      @account.enable_contact_custom_sso!(entrypoint_url: 'some_login_link')
    end
    assert_equal mock.verify, true
  ensure
    Account.any_instance.unstub(:freshid_org_v2_enabled?)
  end

  def test_enable_agent_custom_sso_without_freshid_disabled
    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(false)
    mock = Minitest::Mock.new
    mock.expect(:call, true, ['FRESHID CUSTOM POLICY :: SSO METHODS ::  Enable Agent Custom SSO :: Freshid integeration not enabled'])
    Rails.logger.stub :info, mock do
      @account.enable_agent_custom_sso!(entrypoint_url: 'some_login_link')
    end
    assert_equal mock.verify, true
  ensure
    Account.any_instance.unstub(:freshid_org_v2_enabled?)
  end

  def test_disable_agent_custom_sso
    @account.enable_agent_custom_sso!({entrypoint_url: 'some_login_link'})
    sso = @account.disable_agent_custom_sso!
    assert_equal true, sso
    assert_equal false, @account.sso_enabled
  end

  def test_enable_contact_custom_sso
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    Account.any_instance.stubs(:add_feature).returns(true)
    sso = @account.enable_contact_custom_sso!({entrypoint_url: 'some_login_link'})
    assert_equal true, sso
    assert_equal true, @account.sso_enabled
  ensure
    Account.any_instance.unstub(:freshid_enabled?)
    Account.any_instance.unstub(:add_feature)
  end

  def test_enable_contact_custom_sso_with_freshid_disabled
    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(false)
    Account.any_instance.stubs(:freshid_enabled?).returns(false)
    Account.any_instance.stubs(:add_feature).returns(true)
    @account.enable_contact_custom_sso!(entrypoint_url: 'some_login_link')
    assert_equal false, @account.sso_enabled
  ensure
    Account.any_instance.unstub(:freshid_org_v2_enabled?)
    Account.any_instance.unstub(:freshid_enabled?)
    Account.any_instance.unstub(:add_feature)
  end

  def test_disable_contact_custom_sso
    @account.enable_contact_custom_sso!({entrypoint_url: 'some_login_link'})
    sso = @account.disable_contact_custom_sso!
    assert_equal true, sso
    assert_equal false, @account.sso_enabled
  end

  def test_enable_agent_oidc
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    Account.any_instance.stubs(:add_feature).returns(true)
    sso = @account.enable_agent_oidc_sso!('logout_url')
    assert_equal true, sso
    assert_equal true, @account.sso_enabled
  ensure
    Account.any_instance.unstub(:freshid_enabled?)
    Account.any_instance.unstub(:add_feature)
  end

  def test_disable_agent_oidc
    @account.enable_agent_oidc_sso!('logout_url')
    sso = @account.disable_agent_oidc_sso!
    assert_equal true, sso
    assert_equal false, @account.sso_enabled
  end

  def test_sso_configured
    @account.enable_agent_oidc_sso!('logout_url')
    assert_equal true, @account.sso_configured?
  end

  def test_enable_customer_oidc
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    Account.any_instance.stubs(:add_feature).returns(true)
    sso = @account.enable_customer_oidc_sso!('logout_url')
    assert_equal true, sso
    assert_equal true, @account.sso_enabled
  ensure
    Account.any_instance.unstub(:freshid_enabled?)
    Account.any_instance.unstub(:add_feature)
  end

  def test_disable_customer_oidc
    @account.enable_customer_oidc_sso!('logout_url')
    sso = @account.disable_customer_oidc_sso!
    assert_equal true, sso
    assert_equal false, @account.sso_enabled
  end

  def test_customer_custom_login_url
    sso = @account.account_additional_settings.enable_freshid_custom_policy(custom_policy_addtional_settings_config('contact', 'login_url', 'logout'))
    assert_equal 'login_url', @account.customer_custom_login_url
  end

  def test_agent_custom_login_url
    sso = @account.account_additional_settings.enable_freshid_custom_policy(custom_policy_addtional_settings_config('agent', 'login_url', 'logout'))
    assert_equal 'login_url', @account.agent_custom_login_url
  end

  def test_configure_sso_with_sso_enabled
    @account.sso_enabled = true
    @account.configure_sso_options(sso_type: 'simple', login_url: 'lofin.com')
    assert @account.simple_sso_enabled?
    @account.sso_options[:sso_type] = 'oauth2'
    @account.enable_agent_oauth2_sso!('logout_url')
    assert @account.oauth2_sso_enabled?
    @account.configure_sso_options(sso_type: 'saml', saml_login_url: 'lofin.com', saml_cert_fingerprint: '111:333')
    assert @account.saml_sso_enabled?
  ensure
    @account.reset_sso_options
  end

  def test_reset_sso_when_sso_disabled
    @account.sso_enabled = true
    @account.sso_options = { sso_type: 'oauth2', agent_oauth2: true, agent_oauth2_config: { logout_redirect_url: 'logout.co' } }
    assert @account.oauth2_sso_enabled?
    @account.sso_enabled = false
    Account.any_instance.stubs(:freshid_sso_sync_enabled?).returns(false)
    @account.configure_sso_options({})
    refute @account.oauth2_sso_enabled?
  ensure
    Account.any_instance.unstub(:freshid_sso_sync_enabled?)
    @account.reset_sso_options
  end

  def test_reset_freshdesk_sso_when_sso_disable
    @account.sso_enabled = true
    @account.sso_options = { sso_type: 'simple', login_url: 'abc.com', logout_url: 'xyz.com', agent_oauth2: true, agent_oauth2_config: { logout_redirect_url: 'logout.co' } }
    assert @account.simple_sso_enabled?
    @account.sso_enabled = false
    Account.any_instance.stubs(:freshid_sso_sync_enabled?).returns(true)
    @account.configure_sso_options({})
    refute @account.simple_sso_enabled?
  ensure
    Account.any_instance.unstub(:freshid_sso_sync_enabled?)
    @account.reset_sso_options
  end

  private

    def custom_policy_addtional_settings_config(entity, entrypoint_url, logout_url)
      {
        "#{entity}": {
          entrypoint_url: entrypoint_url,
          entrypoint_id: '181734727304930011',
          entrypoint_title: 'Custom Policy Agent',
          logout_redirect_url: logout_url
        }
      }
    end
end
