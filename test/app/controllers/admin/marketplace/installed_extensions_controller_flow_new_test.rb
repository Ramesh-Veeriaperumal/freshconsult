# frozen_string_literal: true

require_relative '../../../../api/api_test_helper'
require 'webmock/minitest'
['marketplace_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
['subscription_test_helper.rb'].each { |file| require "#{Rails.root}/test/models/helpers/#{file}" }

class Admin::Marketplace::InstalledExtensionsControllerFlowTest < ActionDispatch::IntegrationTest
  include MarketplaceHelper
  include SubscriptionTestHelper
  include Marketplace::Constants

  def test_new_configs
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:extension_details).returns(extension_details_v2_with_configs)
    account_wrap do
      get url_pattern + '/new_configs', params_hash
    end
    assert_response 200
    res_body = JSON.parse(response.body)
    assert_equal 'https://dummy.cloudfront.net/app-assets/1/config/iparams_iframe.html', res_body['configs_url']
  ensure
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:extension_details)
  end

  def test_new_configs_has_config_false
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:extension_details).returns(extension_details_v2)
    account_wrap do
      get url_pattern + '/new_configs', params_hash
    end
    assert_response 200
    res_body = JSON.parse(response.body)
    assert_nil res_body['configs_url']
  ensure
    Admin::Marketplace::ExtensionsController.any_instance.unstub(:extension_details)
  end

  def test_new_configs_has_config_update
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:extension_details).returns(extension_details_v2_with_configs)
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:account_configs).returns(account_configs)
    account_wrap do
      get url_pattern + '/new_configs', params_hash('update')
    end
    assert_response 200
    res_body = JSON.parse(response.body)
    assert_equal "User's Name", res_body['configs']['UserName']
  ensure
    Admin::Marketplace::ExtensionsController.any_instance.unstub(:extension_details)
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:account_configs)
  end

  def test_edit_configs_has_config_update_account_configs_returns_error
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:account_configs).returns(request_with_error_response)
    account_wrap do
      get url_pattern + '/edit_configs', params_hash('update')
    end
    assert_response 503
  ensure
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:account_configs)
  end

  def test_edit_configs
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:extension_details_v2).returns(extension_details_v2_with_configs)
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:account_configs).returns(account_configs)
    account_wrap do
      get url_pattern + '/edit_configs', params_hash('update')
    end
    assert_response 200
    res_body = JSON.parse(response.body)
    assert_equal "User's Name", res_body['configs']['UserName']
  ensure
    Admin::Marketplace::ExtensionsController.any_instance.unstub(:extension_details_v2)
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:account_configs)
  end

  def test_new_oauth_iparams
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:extension_details).returns(extension_details_v2_agent_oauth_with_configs)
    account_wrap do
      get url_pattern + '/new_oauth_iparams', oauth_params_hash
    end
    assert_response 200
    res_body = JSON.parse(response.body)
    assert_nil res_body['configs_url']
  ensure
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:extension_details)
  end

  def test_new_oauth_iparams_has_config_false
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:extension_details).returns(extension_details_v2_agent_oauth_with_configs)
    account_wrap do
      get url_pattern + '/new_oauth_iparams', params_hash
    end
    assert_response 200
    res_body = JSON.parse(response.body)
    assert_nil res_body['configs_url']
  ensure
    Admin::Marketplace::ExtensionsController.any_instance.unstub(:extension_details)
  end

  def test_new_oauth_iparams_has_config_update
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:extension_details).returns(extension_details_v2_with_configs)
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:account_configs).returns(account_configs(true))
    account_wrap do
      get url_pattern + '/new_oauth_iparams', oauth_params_hash('settings')
    end
    assert_response 200
  ensure
    Admin::Marketplace::ExtensionsController.any_instance.unstub(:extension_details)
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:account_configs)
  end

  def test_new_oauth_iparams_has_config_update_raises_error
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:extension_details).returns(extension_details_v2_with_configs)
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:account_configs).raises(StandardError)
    account_wrap do
      get url_pattern + '/new_oauth_iparams', oauth_params_hash('settings')
    end
    assert_response 503
  ensure
    Admin::Marketplace::ExtensionsController.any_instance.unstub(:extension_details)
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:account_configs)
  end

  def test_edit_oauth_iparams_has_config_update_extenstion_configs_returns_error
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:extension_details).returns(request_with_error_response)
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:account_configs).returns(account_configs)
    account_wrap do
      get url_pattern + '/edit_oauth_iparams', params_hash('update')
    end
    assert_response 503
  ensure
    Admin::Marketplace::ExtensionsController.any_instance.unstub(:extension_details)
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:account_configs)
  end

  def test_edit_oauth_iparams_has_config_update_account_configs_returns_error
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:account_configs).returns(request_with_error_response)
    account_wrap do
      get url_pattern + '/edit_oauth_iparams', params_hash('update')
    end
    assert_response 503
  ensure
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:account_configs)
  end

  def test_edit_oauth_iparams
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:extension_details).returns(extension_details_v2_agent_oauth_with_configs)
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:account_configs).returns(account_configs(true))
    account_wrap do
      get url_pattern + '/edit_oauth_iparams', params_hash('update')
    end
    assert_response 200
  ensure
    Admin::Marketplace::ExtensionsController.any_instance.unstub(:extension_details)
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:account_configs)
  end

  def test_edit_oauth_iparams_raises_error
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:extension_details).returns(extension_details_v2_agent_oauth_with_configs)
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:account_configs).raises(StandardError)
    account_wrap do
      get url_pattern + '/edit_oauth_iparams', params_hash('update')
    end
    assert_response 503
  ensure
    Admin::Marketplace::ExtensionsController.any_instance.unstub(:extension_details)
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:account_configs)
  end

  def test_oauth_install
    account_wrap do
      get url_pattern + '/oauth_install', basic_hash
    end
    assert_response 200
  end

  def test_edit_oauth_configs
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:extension_details).returns(extension_details_v2_with_configs)
    account_wrap do
      get url_pattern + '/edit_oauth_configs', basic_hash
    end
    assert_response 200
  ensure
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:extension_details)
  end

  def test_edit_oauth_configs_returns_error
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:extension_details).returns(request_with_error_response)
    account_wrap do
      get url_pattern + '/edit_oauth_configs', basic_hash
    end
    assert_response 503
  ensure
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:extension_details)
  end

  def test_install
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:extension_details).returns(extension_details_v2_with_configs)
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:install_extension).returns(success_response)
    Subscription.any_instance.stubs(:offline_subscription?).returns(true)
    account_wrap do
      post url_pattern_with_only_extension_id(1) + '/install', install_params_hash
    end
    assert_response 200
    assert_equal ' ', response.body
  ensure
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:extension_details)
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:install_extension)
    Subscription.any_instance.unstub(:offline_subscription?)
  end

  def test_install_with_paid_app_error
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:extension_details).returns(extension_details_v2_with_addons)
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:install_extension).returns(success_response)
    Subscription.any_instance.stubs(:offline_subscription?).returns(false)
    Subscription.any_instance.stubs(:trial?).returns(false)
    account_wrap do
      post url_pattern_with_only_extension_id(1) + '/install', install_params_hash
    end
    assert_response 400
  ensure
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:extension_details)
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:install_extension)
    Subscription.any_instance.unstub(:offline_subscription?)
    Subscription.any_instance.unstub(:trial?)
  end

  def test_install_with_oauth_app_success_response
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:extension_details).returns(extension_details_v2_agent_oauth_with_configs(['backend', 'agent_oauth', 'oauth']))
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:install_extension).returns(success_response)
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:fetch_tokens).returns(response_with_simple_hash)
    Subscription.any_instance.stubs(:offline_subscription?).returns(false)
    account_wrap do
      post url_pattern_with_only_extension_id(1) + '/install', install_params_hash
    end
    assert_response 200
    assert_equal ' ', response.body
  ensure
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:extension_details)
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:install_extension)
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:fetch_tokens)
    Subscription.any_instance.unstub(:offline_subscription?)
  end

  def test_install_with_oauth_app_failure_response
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:extension_details).returns(extension_details_v2_agent_oauth_with_configs(['backend', 'agent_oauth', 'oauth']))
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:install_extension).returns(success_response)
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:fetch_tokens).returns(request_with_error_response)
    Subscription.any_instance.stubs(:offline_subscription?).returns(false)
    account_wrap do
      post url_pattern_with_only_extension_id(1) + '/install', install_params_hash
    end
    assert_response 200
    assert_equal ' ', response.body
  ensure
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:extension_details)
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:install_extension)
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:fetch_tokens)
    Subscription.any_instance.unstub(:offline_subscription?)
  end

  def test_install_with_install_status_returns_error
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:extension_details).returns(extension_details_v2_with_configs)
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:install_extension).returns(request_with_error_response)
    Subscription.any_instance.stubs(:offline_subscription?).returns(true)
    account_wrap do
      post url_pattern_with_only_extension_id(1) + '/install', install_params_hash
    end
    assert_response 503
  ensure
    Admin::Marketplace::ExtensionsController.any_instance.unstub(:extension_details)
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:install_extension)
    Subscription.any_instance.unstub(:offline_subscription?)
  end

  def test_install_with_extension_details_returns_error
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:extension_details).returns(request_with_error_response)
    Subscription.any_instance.stubs(:offline_subscription?).returns(true)
    account_wrap do
      post url_pattern_with_only_extension_id(1) + '/install', install_params_hash
    end
    assert_response 503
  ensure
    Admin::Marketplace::ExtensionsController.any_instance.unstub(:extension_details)
    Subscription.any_instance.unstub(:offline_subscription?)
  end

  def test_uninstall
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:extension_details).returns(extension_details_v2_with_configs)
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:uninstall_extension).returns(success_response)
    account_wrap do
      delete url_pattern_with_only_extension_id(1) + '/uninstall', install_params_hash
    end
    assert_response 200
    assert_equal ' ', response.body
  ensure
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:extension_details)
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:uninstall_extension)
  end

  def test_uninstall_with_install_status_returns_error
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:extension_details).returns(extension_details_v2_with_configs)
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:uninstall_extension).returns(request_with_error_response)
    account_wrap do
      delete url_pattern_with_only_extension_id(1) + '/uninstall', install_params_hash
    end
    assert_response 503
  ensure
    Admin::Marketplace::ExtensionsController.any_instance.unstub(:extension_details)
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:uninstall_extension)
  end

  def test_uninstall_with_extension_details_returns_error
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:extension_details).returns(request_with_error_response)
    account_wrap do
      delete url_pattern_with_only_extension_id(1) + '/uninstall', install_params_hash
    end
    assert_response 503
  ensure
    Admin::Marketplace::ExtensionsController.any_instance.unstub(:extension_details)
  end

  def test_reinstall
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:extension_details).returns(extension_details_v2_with_configs_and_addons(4))
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:installed_extension_details).returns(extension_details_v2_with_configs_and_addons)
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:version_details).returns(extension_details_v2_with_configs_and_addons(4))
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:update_extension).returns(success_response)
    Subscription.any_instance.stubs(:offline_subscription?).returns(true)
    account_wrap do
      put url_pattern_with_only_extension_id(1) + '/reinstall', reinstall_params_hash
    end
    assert_response 200
  ensure
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:extension_details)
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:update_extension)
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:version_details)
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:update_extension)
    Subscription.any_instance.unstub(:offline_subscription?)
  end

  def test_reinstall_with_same_version
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:extension_details).returns(extension_details_v2_with_configs_and_addons)
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:installed_extension_details).returns(extension_details_v2_with_configs_and_addons('3'))
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:version_details).returns(extension_details_v2_with_configs_and_addons)
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:update_extension).returns(success_response)
    Subscription.any_instance.stubs(:offline_subscription?).returns(true)
    account_wrap do
      put url_pattern_with_only_extension_id(1) + '/reinstall', reinstall_params_hash(3, 3)
    end
    assert_response 200
    assert_equal ' ', response.body
  ensure
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:extension_details)
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:update_extension)
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:version_details)
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:update_extension)
    Subscription.any_instance.unstub(:offline_subscription?)
  end

  def test_reinstall_with_install_status_returns_error
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:extension_details).returns(extension_details_v2_with_configs)
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:update_extension).returns(request_with_error_response)
    Subscription.any_instance.stubs(:offline_subscription?).returns(true)
    account_wrap do
      put url_pattern_with_only_extension_id(1) + '/reinstall', reinstall_params_hash(2, 1)
    end
    assert_response 503
  ensure
    Admin::Marketplace::ExtensionsController.any_instance.unstub(:extension_details)
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:update_extension)
    Subscription.any_instance.unstub(:offline_subscription?)
  end

  def test_reinstall_with_extension_details_returns_error
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:extension_details).returns(request_with_error_response)
    Subscription.any_instance.stubs(:offline_subscription?).returns(true)
    account_wrap do
      put url_pattern_with_only_extension_id(1) + '/reinstall', reinstall_params_hash(2, 1)
    end
    assert_response 503
  ensure
    Admin::Marketplace::ExtensionsController.any_instance.unstub(:extension_details)
    Subscription.any_instance.unstub(:offline_subscription?)
  end

  def test_enable
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:update_extension).returns(success_response)
    account_wrap do
      put url_pattern_with_only_extension_id + '/enable', enable_params_hash
    end
    assert_response 200
    assert_equal ' ', response.body
  ensure
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:update_extension)
  end

  def test_enable_with_install_status_returns_error
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:update_extension).returns(request_with_error_response)
    account_wrap do
      put url_pattern_with_only_extension_id + '/enable', enable_params_hash
    end
    assert_response 503
  ensure
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:update_extension)
  end

  def test_disable
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:update_extension).returns(success_response)
    account_wrap do
      put url_pattern_with_only_extension_id + '/disable', enable_params_hash
    end
    assert_response 200
    assert_equal ' ', response.body
  ensure
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:update_extension)
  end

  def test_disable_with_install_status_returns_error
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:update_extension).returns(request_with_error_response)
    account_wrap do
      put url_pattern_with_only_extension_id + '/disable', enable_params_hash
    end
    assert_response 503
  ensure
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:update_extension)
  end

  def test_app_status_when_returns_202
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:fetch_app_status).returns(success_response(202))
    account_wrap do
      get url_pattern_with_only_extension_id + '/app_status', enable_params_hash
    end
    assert_response 202
  ensure
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:fetch_app_status)
  end

  def test_app_status_returns_error
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:fetch_app_status).returns(request_with_error_response)
    account_wrap do
      get url_pattern_with_only_extension_id + '/app_status', enable_params_hash
    end
    assert_response 503
  ensure
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:fetch_app_status)
  end

  def test_update_config
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:update_extension).returns(success_response)
    account_wrap do
      put url_pattern_with_only_extension_id + '/update_config', enable_params_hash.merge(configs: { 'oauth_configs' => { 'success' => true } }.to_json)
    end
    assert_response 200
    assert_equal ' ', response.body
  ensure
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:update_extension)
  end

  def test_update_config_with_install_status_returns_error
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:update_extension).returns(request_with_error_response)
    account_wrap do
      put url_pattern_with_only_extension_id + '/update_config', enable_params_hash.merge(configs: '{}')
    end
    assert_response 503
  ensure
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:update_extension)
  end

  def test_iframe_configs
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:iframe_settings).returns(iframe_configs)
    account_wrap do
      get url_pattern + '/iframe_configs', params_hash
    end
    assert_response 200
    res_body = JSON.parse(response.body)
    assert_equal 'https://local.freshpipe.io/app/settings?fd=ext.hxzBKU-by8wqdrlPmVkStjKrgDIzJ-B_HLyb_VYi-WnyNn4xbQ3jrzCkM1vpjXWc-def-ZJf9n3ZKfXEcdOEHviMdSIH2nM2d79hDayzSwW-vfr-SKkxue3Zt49Q.4RUN-_VZ9ge39ZjZ9_HoKg.9ZS-gvh-huhj-Pz3euIG_84CUEgvQ5XEkLP_yX3yKVTyOe2zx_i6JAZsqQQkyE0nfgPhmbR1-UvAdBvLMviH72Xm4Hm4aZFl2R8DFx2M3gfX-gKLKWYP5Mds_45OShYbtkorrX_R5A1NB_IS6i88nf5gmRvULW0X5WfahwcgEyCLgAnAIHBHrvkE.s-rGHHMXm9bKJoiP0ZxRFg', res_body['iframe_url']
  ensure
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:iframe_settings)
  end

  def test_iframe_configs_returns_400
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:iframe_settings).returns(iframe_configs(false))
    account_wrap do
      get url_pattern + '/iframe_configs', params_hash
    end
    assert_response 400
  ensure
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:iframe_settings)
  end

  def test_iframe_configs_with_install_status_returns_error
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:iframe_settings).returns(request_with_error_response)
    account_wrap do
      get url_pattern + '/iframe_configs', params_hash
    end
    assert_response 503
  ensure
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:iframe_settings)
  end

  def test_oauth_callback
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:extension_details).returns(extension_details_v2_agent_oauth_with_configs)
    account_wrap do
      get url_pattern + '/oauth_callback', basic_hash.merge(code: '200')
    end
    assert_response 302
    assert_redirected_to '/a/integrations/applications/#1_configs'
  ensure
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:extension_details)
  end

  def test_oauth_callback_with_is_reauthorize
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:extension_details).returns(extension_details_v2_agent_oauth_with_configs)
    account_wrap do
      get url_pattern + '/oauth_callback', basic_hash.merge(is_reauthorize: true)
    end
    assert_response 302
    assert_redirected_to '/a/integrations/applications/'
    assert_equal I18n.t('marketplace.install_action.success'), flash[:notice]
  ensure
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:extension_details)
  end

  def test_oauth_callback_without_is_reauthorize
    Admin::Marketplace::InstalledExtensionsController.any_instance.stubs(:extension_details).returns(extension_details_v2_agent_oauth_with_configs)
    account_wrap do
      get url_pattern + '/oauth_callback', basic_hash
    end
    assert_response 302
    assert_redirected_to '/a/integrations/applications/'
    assert_equal I18n.t('marketplace.install_action.auth_error'), flash[:notice]
  ensure
    Admin::Marketplace::InstalledExtensionsController.any_instance.unstub(:extension_details)
  end

  private

    def old_ui?
      true
    end

    def params_hash(installation_type = 'install')
      { version: :private, format: :json, type: "#{EXTENSION_TYPE[:plug]},#{EXTENSION_TYPE[:ni]},#{EXTENSION_TYPE[:external_app]}", display_name: 'google_plug', installation_type: installation_type }
    end

    def oauth_params_hash(installation_type = 'install')
      { version: :private, format: :json, display_name: 'google_plug', installation_type: installation_type, is_oauth_app: true, type: EXTENSION_TYPE[:custom_app] }
    end

    def install_params_hash
      { version: :private, format: :json, configs: { 'isInstalled' => true }.to_json }
    end

    def reinstall_params_hash(version_id = 4, installed_version_id = 3)
      { version: :private, format: :json, installed_version: installed_version_id, version_id: version_id }
    end

    def enable_params_hash
      { version: :private, format: :json, version_id: 1 }
    end

    def basic_hash(sample_hash = {})
      { version: :private, format: :json }.merge(sample_hash)
    end

    def url_pattern(extension_id = 1, version_id = 1)
      "/admin/marketplace/installed_extensions/#{extension_id}/#{version_id}"
    end

    def url_pattern_with_only_extension_id(extension_id = 7656)
      "/admin/marketplace/installed_extensions/#{extension_id}"
    end
end
