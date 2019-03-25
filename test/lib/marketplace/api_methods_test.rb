require_relative '../../api/unit_test_helper'

class ApiMethodsTest < ActionView::TestCase
  include Marketplace::ApiMethods

  def setup
    Account.stubs(:current).returns(Account.first)
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_oauth_handshake
    ApiMethodsTest.any_instance.stubs(:params).returns(extension_id: 1, version_id: 1, installed_extn_id: 1)
    ApiMethodsTest.any_instance.stubs(:request).returns(Helpdesk::Note.new)
    Helpdesk::Note.any_instance.stubs(:protocol).returns('http')
    Helpdesk::Note.any_instance.stubs(:host_with_port).returns('test:3000')
    oauth_url = oauth_handshake
    assert_equal true, oauth_url.start_with?('http://')
  end

  def test_mkp_extensions_nil
    MemcacheKeys.stubs(:get_from_cache).returns(nil)
    MemcacheKeys.stubs(:cache).returns(nil)
    FreshRequest::Client.any_instance.stubs(:get).returns(nil)
    ext = mkp_extensions
    assert_equal nil, ext
  end

  def test_mkp_extensions_error
    MemcacheKeys.stubs(:get_from_cache).returns(nil)
    MemcacheKeys.stubs(:cache).returns(nil)
    FreshRequest::Client.any_instance.stubs(:get).raises(FreshRequest::NetworkError.new('network err'))
    ext = mkp_extensions
    assert_equal nil, ext
  end

  def test_mkp_custom_apps
    MemcacheKeys.stubs(:get_from_cache).returns(nil)
    MemcacheKeys.stubs(:cache).returns(nil)
    FreshRequest::Client.any_instance.stubs(:get).returns(nil)
    ext = mkp_custom_apps
    assert_equal nil, ext
  end

  def test_mkp_custom_apps_error
    MemcacheKeys.stubs(:get_from_cache).returns(nil)
    MemcacheKeys.stubs(:cache).returns(nil)
    FreshRequest::Client.any_instance.stubs(:get).raises(FreshRequest::NetworkError.new('network err'))
    ext = mkp_custom_apps
    assert_equal nil, ext
  end

  def test_search_mkp_extensions
    FreshRequest::Client.any_instance.stubs(:get).returns(true)
    search = search_mkp_extensions
    assert_equal true, search
  end

  def test_search_mkp_extensions_err
    FreshRequest::Client.any_instance.stubs(:get).raises(FreshRequest::NetworkError.new('network err'))
    search = search_mkp_extensions
    assert_equal nil, search
  end

  def test_auto_suggest_mkp_extensions
    FreshRequest::Client.any_instance.stubs(:get).returns(true)
    mkp_ext = auto_suggest_mkp_extensions
    assert_equal true, mkp_ext
  end

  def test_auto_suggest_mkp_extensions_err
    FreshRequest::Client.any_instance.stubs(:get).raises(FreshRequest::NetworkError.new('network err'))
    mkp_ext = auto_suggest_mkp_extensions
    assert_equal nil, mkp_ext
  end

  def test_extension_details
    MemcacheKeys.stubs(:get_from_cache).returns(nil)
    MemcacheKeys.stubs(:cache).returns(nil)
    FreshRequest::Client.any_instance.stubs(:get).returns(nil)
    extension = extension_details(1, 1)
    assert_equal nil, extension
  end

  def test_extension_details_err
    MemcacheKeys.stubs(:get_from_cache).returns(nil)
    MemcacheKeys.stubs(:cache).returns(nil)
    FreshRequest::Client.any_instance.stubs(:get).raises(FreshRequest::NetworkError.new('network err'))
    extension = extension_details(1, 1)
    assert_equal nil, extension
  end

  def test_extension_details_v2
    MemcacheKeys.stubs(:get_from_cache).returns(nil)
    MemcacheKeys.stubs(:cache).returns(nil)
    FreshRequest::Client.any_instance.stubs(:get).returns(nil)
    extension = extension_details_v2(1, 1)
    assert_equal nil, extension
  end

  def test_extension_details_v2_err
    MemcacheKeys.stubs(:get_from_cache).returns(nil)
    MemcacheKeys.stubs(:cache).returns(nil)
    FreshRequest::Client.any_instance.stubs(:get).raises(FreshRequest::NetworkError.new('network err'))
    extension = extension_details_v2(1, 1)
    assert_equal nil, extension
  end

  def test_version_details
    MemcacheKeys.stubs(:get_from_cache).returns(nil)
    MemcacheKeys.stubs(:cache).returns(nil)
    FreshRequest::Client.any_instance.stubs(:get).returns(nil)
    extension = version_details(1)
    assert_equal nil, extension
  end

  def test_version_details_error
    MemcacheKeys.stubs(:get_from_cache).returns(nil)
    MemcacheKeys.stubs(:cache).returns(nil)
    FreshRequest::Client.any_instance.stubs(:get).raises(FreshRequest::NetworkError.new('network err'))
    extension = version_details(1)
    assert_equal nil, extension
  end

  def test_v2_versions
    MemcacheKeys.stubs(:get_from_cache).returns(nil)
    MemcacheKeys.stubs(:cache).returns(nil)
    FreshRequest::Client.any_instance.stubs(:get).returns(nil)
    extension = v2_versions
    assert_equal nil, extension
  end

  def test_v2_versions_err
    MemcacheKeys.stubs(:get_from_cache).returns(nil)
    MemcacheKeys.stubs(:cache).returns(nil)
    FreshRequest::Client.any_instance.stubs(:get).raises(FreshRequest::NetworkError.new('network err'))
    extension = v2_versions
    assert_equal nil, extension
  end

  def test_all_categories
    MemcacheKeys.stubs(:get_from_cache).returns(nil)
    MemcacheKeys.stubs(:cache).returns(nil)
    FreshRequest::Client.any_instance.stubs(:get).returns(nil)
    categories = all_categories
    assert_equal nil, categories
  end

  def test_all_categories_err
    MemcacheKeys.stubs(:get_from_cache).returns(nil)
    MemcacheKeys.stubs(:cache).returns(nil)
    FreshRequest::Client.any_instance.stubs(:get).raises(FreshRequest::NetworkError.new('network err'))
    categories = all_categories
    assert_equal nil, categories
  end

  def test_extension_configs
    MemcacheKeys.stubs(:get_from_cache).returns(nil)
    MemcacheKeys.stubs(:cache).returns(nil)
    FreshRequest::Client.any_instance.stubs(:get).returns(nil)
    configs = extension_configs
    assert_equal nil, configs
  end

  def test_extension_configs_err
    MemcacheKeys.stubs(:get_from_cache).returns(nil)
    MemcacheKeys.stubs(:cache).returns(nil)
    FreshRequest::Client.any_instance.stubs(:get).raises(FreshRequest::NetworkError.new('network err'))
    configs = extension_configs
    assert_equal nil, configs
  end

  def test_ni_latest_details
    MemcacheKeys.stubs(:get_from_cache).returns(nil)
    MemcacheKeys.stubs(:cache).returns(nil)
    FreshRequest::Client.any_instance.stubs(:get).returns(nil)
    details = ni_latest_details('appname')
    assert_equal nil, details
  end

  def test_ni_latest_details_err
    MemcacheKeys.stubs(:get_from_cache).returns(nil)
    MemcacheKeys.stubs(:cache).returns(nil)
    FreshRequest::Client.any_instance.stubs(:get).raises(FreshRequest::NetworkError.new('network err'))
    details = ni_latest_details('appname')
    assert_equal nil, details
  end

  def test_iframe_settings
    MemcacheKeys.stubs(:get_from_cache).returns(nil)
    MemcacheKeys.stubs(:cache).returns(nil)
    FreshRequest::Client.any_instance.stubs(:get).returns(nil)
    configs = iframe_settings
    assert_equal nil, configs
  end

  def test_iframe_settings_err
    MemcacheKeys.stubs(:get_from_cache).returns(nil)
    MemcacheKeys.stubs(:cache).returns(nil)
    FreshRequest::Client.any_instance.stubs(:get).raises(FreshRequest::NetworkError.new('network err'))
    configs = iframe_settings
    assert_equal nil, configs
  end

  def test_install_status
    ApiMethodsTest.any_instance.stubs(:error_status?).returns(false)
    ApiMethodsTest.any_instance.stubs(:extension_details).returns(Helpdesk::Note.new)
    Helpdesk::Note.any_instance.stubs(:body).returns('extension_id' => 1)
    MemcacheKeys.stubs(:get_from_cache).returns(nil)
    MemcacheKeys.stubs(:cache).returns(nil)
    FreshRequest::Client.any_instance.stubs(:get).returns(nil)
    configs = install_status
    assert_equal nil, configs
  end

  def test_install_status_err
    ApiMethodsTest.any_instance.stubs(:error_status?).returns(false)
    ApiMethodsTest.any_instance.stubs(:extension_details).returns(Helpdesk::Note.new)
    Helpdesk::Note.any_instance.stubs(:body).returns('extension_id' => 1)
    MemcacheKeys.stubs(:get_from_cache).returns(nil)
    MemcacheKeys.stubs(:cache).returns(nil)
    FreshRequest::Client.any_instance.stubs(:get).raises(FreshRequest::NetworkError.new('network err'))
    configs = install_status
    assert_equal nil, configs
  end

  def test_account_configs
    MemcacheKeys.stubs(:get_from_cache).returns(nil)
    MemcacheKeys.stubs(:cache).returns(nil)
    FreshRequest::Client.any_instance.stubs(:get).returns(nil)
    configs = account_configs
    assert_equal nil, configs
  end

  def test_account_configs_err
    MemcacheKeys.stubs(:get_from_cache).returns(nil)
    MemcacheKeys.stubs(:cache).returns(nil)
    FreshRequest::Client.any_instance.stubs(:get).raises(FreshRequest::NetworkError.new('network err'))
    configs = account_configs
    assert_equal nil, configs
  end

  def test_install_extension
    ApiMethodsTest.any_instance.stubs(:post_api).returns(Helpdesk::Note.new)
    Helpdesk::Note.any_instance.stubs(:status).returns(500)
    extension = install_extension({})
    assert_equal nil, extension.id
  end

  def test_install_extension_err
    ApiMethodsTest.any_instance.stubs(:post_api).raises(FreshRequest::NetworkError.new('network err'))
    extension = install_extension({})
    assert_equal nil, extension
  end

  def test_update_extension
    MemcacheKeys.stubs(:delete_from_cache).returns(true)
    FreshRequest::Client.any_instance.stubs(:put).returns(nil)
    extension = update_extension(extension_id: 1)
    assert_equal nil, extension
  end

  def test_update_extension_error
    MemcacheKeys.stubs(:delete_from_cache).returns(true)
    FreshRequest::Client.any_instance.stubs(:put).raises(FreshRequest::NetworkError.new('network err'))
    extension = update_extension(extension_id: 1)
    assert_equal nil, extension
  end

  def test_uninstall_extension
    MemcacheKeys.stubs(:delete_from_cache).returns(true)
    FreshRequest::Client.any_instance.stubs(:delete).returns(nil)
    extension = uninstall_extension(extension_id: 1)
    assert_equal nil, extension
  end

  def test_uninstall_extension_err
    MemcacheKeys.stubs(:delete_from_cache).returns(true)
    FreshRequest::Client.any_instance.stubs(:delete).raises(FreshRequest::NetworkError.new('network err'))
    extension = uninstall_extension(extension_id: 1)
    assert_equal nil, extension
  end

  def test_installed_extensions
    FreshRequest::Client.any_instance.stubs(:get).returns(nil)
    extensions = installed_extensions
    assert_equal nil, extensions
  end

  def test_installed_extensions_error
    FreshRequest::Client.any_instance.stubs(:get).raises(FreshRequest::NetworkError.new('network err'))
    extensions = installed_extensions
    assert_equal nil, extensions
  end

  def test_installed_extension_details
    FreshRequest::Client.any_instance.stubs(:get).returns(nil)
    extensions = installed_extension_details(1)
    assert_equal nil, extensions
  end

  def test_installed_extension_details_err
    FreshRequest::Client.any_instance.stubs(:get).raises(FreshRequest::NetworkError.new('network err'))
    extensions = installed_extension_details(1)
    assert_equal nil, extensions
  end

  def test_fetch_tokens
    FreshRequest::Client.any_instance.stubs(:get).returns(nil)
    extensions = fetch_tokens
    assert_equal nil, extensions
  end

  def test_fetch_tokens_error
    FreshRequest::Client.any_instance.stubs(:get).raises(FreshRequest::NetworkError.new('network err'))
    extensions = fetch_tokens
    assert_equal nil, extensions
  end

  def test_fetch_app_status
    FreshRequest::Client.any_instance.stubs(:get).returns(nil)
    extensions = fetch_app_status(1)
    assert_equal nil, extensions
  end

  def test_fetch_app_status_error
    FreshRequest::Client.any_instance.stubs(:get).raises(FreshRequest::NetworkError.new('network err'))
    extensions = fetch_app_status(1)
    assert_equal nil, extensions
  end

  def test_fetch_installed_extensions
    FreshRequest::Client.any_instance.stubs(:get).returns(nil)
    extensions = fetch_installed_extensions(1, [1])
    assert_equal nil, extensions
  end

  def test_fetch_installed_extensions_error
    FreshRequest::Client.any_instance.stubs(:get).raises(FreshRequest::NetworkError.new('network err'))
    extensions = fetch_installed_extensions(1, [1])
    assert_equal nil, extensions
  end

  def test_fetch_extension_details
    FreshRequest::Client.any_instance.stubs(:get).returns(nil)
    extensions = fetch_extension_details(1)
    assert_equal nil, extensions
  end

  def test_fetch_extension_details_error
    FreshRequest::Client.any_instance.stubs(:get).raises(FreshRequest::NetworkError.new('network err'))
    extensions = fetch_extension_details(1)
    assert_equal nil, extensions
  end
end
