require_relative '../../api/unit_test_helper'
require Rails.root.join('spec', 'support', 'user_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class HelperMethodsTest < ActionView::TestCase
  include Marketplace::HelperMethods

  def setup
    @account = Account.first || create_test_account
    Account.stubs(:current).returns(@account)
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_paid_app_params_new_gallery_salesforce
    HelperMethodsTest.any_instance.stubs(:extension_name).returns('salesforce_v2')
    HelperMethodsTest.any_instance.stubs(:get_others_redis_hash).returns('addon_id' => 'dummycache', 'install_type' => 'trial')
    HelperMethodsTest.any_instance.stubs(:remove_others_redis_key).returns(true)
    Account.any_instance.stubs(:marketplace_gallery_enabled?).returns(true)
    params = paid_app_params
    assert_equal(params[:billing][:addon_id], 'dummycache')
    assert_equal(params[:billing][:trial_period], 30)
  ensure
    Account.any_instance.unstub(:marketplace_gallery_enabled?)
    HelperMethodsTest.any_instance.unstub(:get_others_redis_hash)
    HelperMethodsTest.any_instance.unstub(:remove_others_redis_key)
    HelperMethodsTest.any_instance.unstub(:extension_name)
  end

  def test_paid_app_params_new_gallery_dynamics
    HelperMethodsTest.any_instance.stubs(:extension_name).returns('dynamics_v2')
    HelperMethodsTest.any_instance.stubs(:get_others_redis_hash).returns('addon_id' => 'dummycache', 'install_type' => 'trial')
    HelperMethodsTest.any_instance.stubs(:remove_others_redis_key).returns(true)
    Account.any_instance.stubs(:marketplace_gallery_enabled?).returns(true)
    params = paid_app_params
    assert_equal(params[:billing][:addon_id], 'dummycache')
    assert_equal(params[:billing][:trial_period], 30)
  ensure
    Account.any_instance.unstub(:marketplace_gallery_enabled?)
    HelperMethodsTest.any_instance.unstub(:get_others_redis_hash)
    HelperMethodsTest.any_instance.unstub(:remove_others_redis_key)
    HelperMethodsTest.any_instance.unstub(:extension_name)
  end

  def test_paid_app_params_new_gallery_salesforce_without_trial
    HelperMethodsTest.any_instance.stubs(:extension_name).returns('salesforce_v2')
    HelperMethodsTest.any_instance.stubs(:get_others_redis_hash).returns('addon_id' => 'dummycache', 'install_type' => 'paid')
    HelperMethodsTest.any_instance.stubs(:remove_others_redis_key).returns(true)
    Account.any_instance.stubs(:marketplace_gallery_enabled?).returns(true)
    params = paid_app_params
    assert_equal(params[:billing][:addon_id], 'dummycache')
    assert_equal(params[:billing][:trial_period], nil)
  ensure
    Account.any_instance.unstub(:marketplace_gallery_enabled?)
    HelperMethodsTest.any_instance.unstub(:get_others_redis_hash)
    HelperMethodsTest.any_instance.unstub(:remove_others_redis_key)
    HelperMethodsTest.any_instance.unstub(:extension_name)
  end

  def test_paid_app_params_new_gallery_salesforce_delete
    HelperMethodsTest.any_instance.stubs(:extension_name).returns('salesforce_v2')
    HelperMethodsTest.any_instance.stubs(:get_others_redis_hash).returns('addon_id' => 'dummycache', 'install_type' => nil)
    HelperMethodsTest.any_instance.stubs(:remove_others_redis_key).returns(true)
    Account.any_instance.stubs(:marketplace_gallery_enabled?).returns(true)
    params = paid_app_params
    assert_equal(params[:billing][:addon_id], 'dummycache')
    assert_equal(params[:billing][:trial_period], nil)
  ensure
    Account.any_instance.unstub(:marketplace_gallery_enabled?)
    HelperMethodsTest.any_instance.unstub(:get_others_redis_hash)
    HelperMethodsTest.any_instance.unstub(:remove_others_redis_key)
    HelperMethodsTest.any_instance.unstub(:extension_name)
  end

  def test_paid_app_params_new_gallery_salesforce_error
    HelperMethodsTest.any_instance.stubs(:extension_name).returns('salesforce_v2')
    HelperMethodsTest.any_instance.stubs(:get_others_redis_hash).returns({})
    HelperMethodsTest.any_instance.stubs(:remove_others_redis_key).returns({})
    HelperMethodsTest.any_instance.stubs(:trial_subscription?).returns(false)
    Account.any_instance.stubs(:marketplace_gallery_enabled?).returns(true)
    params = paid_app_params
    assert_nil params[:billing][:addon_id]
  ensure
    Account.any_instance.unstub(:marketplace_gallery_enabled?)
    HelperMethodsTest.any_instance.unstub(:get_others_redis_hash)
    HelperMethodsTest.any_instance.unstub(:remove_others_redis_key)
    HelperMethodsTest.any_instance.unstub(:extension_name)
    HelperMethodsTest.any_instance.unstub(:trial_subscription?)
  end

  def test_free_app_params_new_gallery_slack
    HelperMethodsTest.any_instance.stubs(:extension_name).returns('slack_v2')
    HelperMethodsTest.any_instance.stubs(:get_others_redis_hash).returns('dummycache')
    HelperMethodsTest.any_instance.stubs(:remove_others_redis_key).returns(true)
    HelperMethodsTest.any_instance.stubs(:paid_app?).returns(false)
    Account.any_instance.stubs(:marketplace_gallery_enabled?).returns(true)
    params = paid_app_params
    assert_empty(params)
  ensure
    Account.any_instance.unstub(:marketplace_gallery_enabled?)
    HelperMethodsTest.any_instance.unstub(:get_others_redis_hash)
    HelperMethodsTest.any_instance.unstub(:remove_others_redis_key)
    HelperMethodsTest.any_instance.unstub(:extension_name)
    HelperMethodsTest.any_instance.unstub(:paid_app?)
  end

  def test_paid_app_params_new_gallery_custom
    HelperMethodsTest.any_instance.stubs(:extension_name).returns('slack_v2')
    HelperMethodsTest.any_instance.stubs(:get_others_redis_hash).returns('dummycache')
    HelperMethodsTest.any_instance.stubs(:remove_others_redis_key).returns(true)
    HelperMethodsTest.any_instance.stubs(:paid_app?).returns(true)
    HelperMethodsTest.any_instance.stubs(:addon_details).returns('addon_id' => '1234')
    Account.any_instance.stubs(:marketplace_gallery_enabled?).returns(true)
    params = paid_app_params
    assert_equal(params[:billing][:addon_id], '1234')
  ensure
    Account.any_instance.unstub(:marketplace_gallery_enabled?)
    HelperMethodsTest.any_instance.unstub(:get_others_redis_hash)
    HelperMethodsTest.any_instance.unstub(:remove_others_redis_key)
    HelperMethodsTest.any_instance.unstub(:extension_name)
    HelperMethodsTest.any_instance.unstub(:paid_app?)
    HelperMethodsTest.any_instance.unstub(:addon_details)
  end
end
