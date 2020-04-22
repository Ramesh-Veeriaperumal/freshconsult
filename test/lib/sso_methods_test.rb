require_relative '../api/unit_test_helper'

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
  end

  def test_reset_sso_options
    sso = @account.reset_sso_options
    assert_equal basic_sso_hash, sso
  end

  def test_oauth2_sso_enabled
    Account.any_instance.stubs(:sso_options).returns(nil)
    sso = @account.oauth2_sso_enabled?
    assert_equal false, sso
  end

  def test_is_saml_sso
    Account.any_instance.stubs(:sso_options).returns({})
    sso = @account.is_saml_sso?
    assert_equal false, sso
  end

  def test_enable_agent_oauth2_sso
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    Account.any_instance.stubs(:add_feature).returns(true)
    Account.any_instance.stubs(:customer_oauth2_sso_enabled?).returns(false)
    sso = @account.enable_agent_oauth2_sso!('test url')
    assert_equal true, sso
  end

  def test_disable_agent_oauth2_sso
    Account.any_instance.stubs(:agent_oauth2_sso_enabled?).returns(true)
    Account.any_instance.stubs(:sso_options).returns(agent_oauth2: 'oauth2', agent_oauth2_config: 'oauth2_config', sso_type: 'type')
    Account.any_instance.stubs(:customer_oauth2_sso_enabled?).returns(false)
    Account.any_instance.stubs(:reset_feature).returns(true)
    sso = @account.disable_agent_oauth2_sso!
    assert_equal true, sso
  end

  def test_enable_customer_oauth2_sso
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    Account.any_instance.stubs(:add_feature).returns(true)
    Account.any_instance.stubs(:agent_oauth2_sso_enabled?).returns(false)
    sso = @account.enable_customer_oauth2_sso!('test url')
    assert_equal true, sso
  end

  def test_disable_customer_oauth2_sso
    Account.any_instance.stubs(:customer_oauth2_sso_enabled?).returns(true)
    Account.any_instance.stubs(:sso_options).returns(customer_oauth2: 'oauth2', customer_oauth2_config: 'oauth2_config', sso_type: 'type')
    Account.any_instance.stubs(:reset_feature).returns(true)
    Account.any_instance.stubs(:agent_oauth2_sso_enabled?).returns(false)
    sso = @account.disable_customer_oauth2_sso!
    assert_equal true, sso
  end

  def test_remove_oauth2_sso_options
    Account.any_instance.stubs(:revoke_feature).returns(true)
    Account.any_instance.stubs(:sso_options).returns(nil)
    sso = @account.remove_oauth2_sso_options
    assert_equal nil, sso
  end

  def test_agent_oauth2_logout_redirect_url
    Account.any_instance.stubs(:agent_oauth2_sso_enabled?).returns(false)
    sso = @account.agent_oauth2_logout_redirect_url
    assert_equal nil, sso
  end

  def test_customer_oauth2_logout_redirect_url
    Account.any_instance.stubs(:customer_oauth2_sso_enabled?).returns(false)
    sso = @account.customer_oauth2_logout_redirect_url
    assert_equal nil, sso
  end

  def test_freshid_saml_sso_enabled
    Account.any_instance.stubs(:sso_options).returns(nil)
    sso = @account.freshid_saml_sso_enabled?
    assert_equal false, sso
  end

  def test_freshid_sso_enabled
    Account.any_instance.stubs(:sso_options).returns(nil)
    sso = @account.freshid_sso_enabled?
    assert_equal false, sso
  end

  def test_enable_agent_freshid_saml_sso
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    Account.any_instance.stubs(:add_feature).returns(true)
    Account.any_instance.stubs(:customer_freshid_saml_sso_enabled?).returns(false)
    sso = @account.enable_agent_freshid_saml_sso!('test_url')
    assert_equal true, sso
  end

  def test_enable_customer_freshid_saml_sso
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    Account.any_instance.stubs(:add_feature).returns(true)
    Account.any_instance.stubs(:agent_freshid_saml_sso_enabled?).returns(false)
    sso = @account.enable_customer_freshid_saml_sso!('test_url')
    assert_equal true, sso
  end

  def test_disable_agent_freshid_saml_sso
    @account.enable_agent_freshid_saml_sso!('test_url')
    Account.any_instance.stubs(:reset_feature).returns(true)
    sso = @account.disable_agent_freshid_saml_sso!
    assert_equal true, sso
    assert_equal false, @account.sso_enabled
  end

  def test_disable_customer_freshid_saml_sso
    Account.any_instance.stubs(:customer_freshid_saml_sso_enabled?).returns(true)
    Account.any_instance.stubs(:sso_options).returns(customer_freshid_saml: 'customer saml', customer_freshid_saml_config: 'saml config', sso_type: 'type')
    Account.any_instance.stubs(:agent_freshid_saml_sso_enabled?).returns(false)
    Account.any_instance.stubs(:reset_feature).returns(true)
    sso = @account.disable_customer_freshid_saml_sso!
    assert_equal true, sso
  end

  def test_remove_freshid_saml_sso_options
    Account.any_instance.stubs(:revoke_feature).returns(true)
    Account.any_instance.stubs(:sso_options).returns(nil)
    sso = @account.remove_freshid_saml_sso_options
    assert_equal nil, sso
  end

  def test_agent_freshid_saml_logout_redirect_url
    Account.any_instance.stubs(:agent_freshid_saml_sso_enabled?).returns(false)
    sso = @account.agent_freshid_saml_logout_redirect_url
    assert_equal nil, sso
  end

  def test_customer_freshid_saml_logout_redirect_url
    Account.any_instance.stubs(:customer_freshid_saml_sso_enabled?).returns(false)
    sso = @account.customer_freshid_saml_logout_redirect_url
    assert_equal nil, sso
  end

  def test_sso_login_url_with_saml
    Account.any_instance.stubs(:is_saml_sso?).returns(true)
    Account.any_instance.stubs(:sso_options).returns(saml_login_url: 'login_url')
    sso = @account.sso_login_url
    assert_equal 'login_url', sso
  end

  def test_sso_login_url_without_saml
    Account.any_instance.stubs(:is_saml_sso?).returns(false)
    Account.any_instance.stubs(:sso_options).returns(login_url: 'login_url')
    sso = @account.sso_login_url
    assert_equal 'login_url', sso
  end

  def test_sso_logout_url_with_saml
    Account.any_instance.stubs(:is_saml_sso?).returns(true)
    Account.any_instance.stubs(:sso_options).returns(saml_logout_url: 'logout_url')
    sso = @account.sso_logout_url
    assert_equal 'logout_url', sso
  end

  def test_sso_logout_url_without_saml
    Account.any_instance.stubs(:is_saml_sso?).returns(false)
    Account.any_instance.stubs(:sso_options).returns(logout_url: 'logout_url')
    sso = @account.sso_logout_url
    assert_equal 'logout_url', sso
  end

  def test_enable_agent_custom_sso
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    Account.any_instance.stubs(:add_feature).returns(true)
    sso = @account.enable_agent_custom_sso!({entrypoint_url: 'some_login_link'})
    assert_equal true, sso
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
end
