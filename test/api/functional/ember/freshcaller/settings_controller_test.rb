require_relative '../../../test_helper'

class Ember::Freshcaller::SettingsControllerTest < ActionController::TestCase
  include ::Freshcaller::TestHelper

  def wrap_cname(_param)
    {}
  end

  def test_fetch_settings_without_feature
    Account.current.revoke_feature(:freshcaller)
    get :index, controller_params(version: 'private')
    match_json(request_error_pattern(:require_feature, feature: 'freshcaller'.titleize))
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:forbidden]
  end

  def test_fetch_settings_without_freshcaller_account_agent
    Account.current.add_feature(:freshcaller)
    # @controller.stubs(:requires_feature).with(:freshcaller).returns(true)
    get :index, controller_params(version: 'private')
    match_json({:freshcaller_account_enabled => false, :freshcaller_agent_enabled => false})
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:ok]
  ensure
    Account.current.revoke_feature(:freshcaller)
  end

  def test_fetch_settings_with_freshcaller_account
    Account.current.add_feature(:freshcaller)
    # @controller.stubs(:requires_feature).with(:freshcaller).returns(true)
    # As all the accounts are moved to falcon, freshcaller & freshcaller widget is enabled to accounts during signup.
    # account/callbacks.rb:499
    # Modifying the testcase to have the extra keys.
    create_freshcaller_account
    get :index, controller_params(version: 'private')
    match_json(freshcaller_account_enabled: true, freshcaller_agent_enabled: false, freshcaller_widget_url: /\/widget\//, freshid_enabled: false, token: String, fresh_id_version: nil)
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:ok]
  ensure
    delete_freshcaller_account
    Account.current.revoke_feature(:freshcaller)
  end

  def test_fetch_settings_with_freshcaller_enabled_agent
    Account.current.add_feature(:freshcaller)
    # @controller.stubs(:requires_feature).with(:freshcaller).returns(true)
    create_freshcaller_enabled_agent
    get :index, controller_params(version: 'private')
    match_json({:freshcaller_account_enabled => false, :freshcaller_agent_enabled => true})
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:ok]
  ensure
    delete_freshcaller_agent
    Account.current.revoke_feature(:freshcaller)
  end

  def test_fetch_settings_with_freshcaller_and_widget_enabled_agent
    Account.current.add_feature(:freshcaller)
    Account.current.add_feature(:freshcaller_widget)
    # @controller.stubs(:requires_feature).with(:freshcaller).returns(true)
    create_freshcaller_account
    create_freshcaller_enabled_agent
    get :index, controller_params(version: 'private')
    match_json(freshcaller_account_enabled: true, freshcaller_agent_enabled: true, freshcaller_widget_url: /\/widget\//, freshid_enabled: false, token: String, fresh_id_version: nil)
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:ok]
  ensure
    delete_freshcaller_agent
    Account.current.revoke_feature(:freshcaller)
    Account.current.revoke_feature(:freshcaller_widget)
    delete_freshcaller_account
  end


  def test_fetch_settings_with_freshcaller_and_widget_and_freshid_enabled_agent
    Account.current.add_feature(:freshcaller)
    Account.current.add_feature(:freshcaller_widget)
    # @controller.stubs(:requires_feature).with(:freshcaller).returns(true)
    @account.stubs(:freshid_enabled?).returns(:true)
    create_freshcaller_account
    create_freshcaller_enabled_agent
    get :index, controller_params(version: 'private')
    match_json(freshcaller_account_enabled: true, freshcaller_agent_enabled: true, freshcaller_widget_url: /\/widget\//, freshid_enabled: 'true', token: NilClass, fresh_id_version: 'V1')
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:ok]
  ensure
    delete_freshcaller_agent
    Account.current.revoke_feature(:freshcaller)
    Account.current.revoke_feature(:freshcaller_widget)
    delete_freshcaller_account
    @account.unstub(:freshid_enabled?)
  end

  def test_fetch_settings_with_freshcaller_disabled_agent
    Account.current.add_feature(:freshcaller)
    # @controller.stubs(:requires_feature).with(:freshcaller).returns(true)
    create_freshcaller_disabled_agent
    get :index, controller_params(version: 'private')
    match_json({:freshcaller_account_enabled => false, :freshcaller_agent_enabled => false})
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:ok]
  ensure
    delete_freshcaller_agent
    Account.current.revoke_feature(:freshcaller)
  end

  def test_fetch_desktop_notification_setting
    # @controller.stubs(:requires_feature).with(:freshcaller).returns(true)
    Account.current.add_feature(:freshcaller)
    @controller.stubs(:get_integ_redis_key).returns(true)
    put :desktop_notification, controller_params(version: 'private')
    match_json(desktop_notification_disabled: true)
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:ok]
  ensure
    Account.current.revoke_feature(:freshcaller)
    # @controller.unstub(:requires_feature)
    @controller.unstub(:get_integ_redis_key)
  end

  def test_fetch_desktop_notification_setting_without_freshcaller_feature
    Account.current.revoke_feature(:freshcaller)
    put :desktop_notification, controller_params(version: 'private')
    match_json(request_error_pattern(:require_feature, feature: 'freshcaller'.titleize))
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:forbidden]
  end

  def test_disable_desktop_notification_setting
    # @controller.stubs(:requires_feature).with(:freshcaller).returns(true)
    Account.current.add_feature(:freshcaller)
    @controller.stubs(:get_integ_redis_key).returns(true)
    put :desktop_notification, controller_params(version: 'private', disable: 'true')
    match_json({:desktop_notification_disabled => true})
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:ok]
  ensure
    Account.current.revoke_feature(:freshcaller)
    # @controller.unstub(:requires_feature)
    @controller.unstub(:get_integ_redis_key)
  end

  def test_freshcaller_redirect_url_without_freshcaller_feature
    Account.current.revoke_feature(:freshcaller)
    get :redirect_url, controller_params(version: 'private')
    match_json(request_error_pattern(:require_feature, feature: 'freshcaller'.titleize))
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:forbidden]
  end

  def test_freshcaller_redirect_url_without_account
    # @controller.stubs(:requires_feature).with(:freshcaller).returns(true)
    Account.current.add_feature(:freshcaller)
    get :redirect_url, controller_params(version: 'private')
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:not_found]
  ensure
    Account.current.revoke_feature(:freshcaller)
  end

  def test_freshcaller_redirect_url_with_account
    # @controller.stubs(:requires_feature).with(:freshcaller).returns(true)
    Account.current.add_feature(:freshcaller)
    create_freshcaller_account
    get :redirect_url, controller_params(version: 'private')
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:ok]
    assert_match("#{@account.freshcaller_account.domain}\/sso\/freshdesk", JSON.parse(response.body)['redirect_url'])
  ensure
    delete_freshcaller_account
    Account.current.revoke_feature(:freshcaller)
  end
end
