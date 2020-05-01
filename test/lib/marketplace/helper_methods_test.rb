require_relative '../../api/unit_test_helper'
require Rails.root.join('spec', 'support', 'user_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class Response
  attr_reader :body, :status, :response_headers

  def initialize(body)
    @body = body
    @status = 200
    @response_headers = {}
  end
end

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

  def extension_details_map(name)
    body = {
      'name' => name,
      'addons' => [
        currency_code: 'us'
      ]
    }
    FreshRequest::Response.new(Response.new(body))
  end

  def test_paid_app_params_new_gallery_salesforce
    Marketplace::HelperMethods.stubs(:extension_details).returns(extension_details_map('salesforce_v2'))
    Marketplace::HelperMethods.stubs(:extension_name).returns('salesforce_v2')
    Marketplace::HelperMethods.stubs(:get_others_redis_key).returns('dummycache')
    Marketplace::HelperMethods.stubs(:remove_others_redis_key).returns(true)
    HelperMethodsTest.any_instance.stubs(:extension_name).returns('salesforce_v2')
    HelperMethodsTest.any_instance.stubs(:get_others_redis_key).returns('dummycache')
    HelperMethodsTest.any_instance.stubs(:remove_others_redis_key).returns(true)
    Account.any_instance.stubs(:marketplace_gallery_enabled?).returns(true)
    params = paid_app_params
    assert_equal(params[:billing][:addon_id], 'dummycache')
  ensure
    Account.any_instance.unstub(:marketplace_gallery_enabled?)
    Marketplace::HelperMethods.unstub(:extension_details)
    Marketplace::HelperMethods.unstub(:get_others_redis_key)
    Marketplace::HelperMethods.unstub(:remove_others_redis_key)
    Marketplace::HelperMethods.unstub(:extension_name)
    HelperMethodsTest.any_instance.unstub(:get_others_redis_key)
    HelperMethodsTest.any_instance.unstub(:remove_others_redis_key)
    HelperMethodsTest.any_instance.unstub(:extension_name)
  end

  def test_paid_app_params_new_gallery_dynamics
    Marketplace::HelperMethods.stubs(:extension_details).returns(extension_details_map('dynamics_v2'))
    Marketplace::HelperMethods.stubs(:extension_name).returns('dynamics_v2')
    Marketplace::HelperMethods.stubs(:get_others_redis_key).returns('dummycache')
    Marketplace::HelperMethods.stubs(:remove_others_redis_key).returns(true)
    HelperMethodsTest.any_instance.stubs(:extension_name).returns('dynamics_v2')
    HelperMethodsTest.any_instance.stubs(:get_others_redis_key).returns('dummycache')
    HelperMethodsTest.any_instance.stubs(:remove_others_redis_key).returns(true)
    Account.any_instance.stubs(:marketplace_gallery_enabled?).returns(true)
    params = paid_app_params
    assert_equal(params[:billing][:addon_id], 'dummycache')
  ensure
    Account.any_instance.unstub(:marketplace_gallery_enabled?)
    Marketplace::HelperMethods.unstub(:extension_details)
    Marketplace::HelperMethods.unstub(:get_others_redis_key)
    Marketplace::HelperMethods.unstub(:remove_others_redis_key)
    Marketplace::HelperMethods.unstub(:extension_name)
    HelperMethodsTest.any_instance.unstub(:get_others_redis_key)
    HelperMethodsTest.any_instance.unstub(:remove_others_redis_key)
    HelperMethodsTest.any_instance.unstub(:extension_name)
  end

  def test_paid_app_params_new_gallery_salesforce_error
    Marketplace::HelperMethods.stubs(:extension_details).returns(extension_details_map('salesforce_v2'))
    Marketplace::HelperMethods.stubs(:extension_name).returns('salesforce_v2')
    HelperMethodsTest.any_instance.stubs(:extension_name).returns('salesforce_v2')
    HelperMethodsTest.any_instance.stubs(:get_others_redis_key).raises(StandardError.new('error'))
    HelperMethodsTest.any_instance.stubs(:remove_others_redis_key).raises(StandardError.new('error'))
    HelperMethodsTest.any_instance.stubs(:trial_subscription?).returns(false)
    Account.any_instance.stubs(:marketplace_gallery_enabled?).returns(true)
    params = paid_app_params
    assert_nil params[:billing][:addon_id]
  ensure
    Account.any_instance.unstub(:marketplace_gallery_enabled?)
    Marketplace::HelperMethods.unstub(:extension_details)
    Marketplace::HelperMethods.unstub(:get_others_redis_key)
    Marketplace::HelperMethods.unstub(:remove_others_redis_key)
    Marketplace::HelperMethods.unstub(:extension_name)
    HelperMethodsTest.any_instance.unstub(:get_others_redis_key)
    HelperMethodsTest.any_instance.unstub(:remove_others_redis_key)
    HelperMethodsTest.any_instance.unstub(:extension_name)
    HelperMethodsTest.any_instance.unstub(:trial_subscription?)
  end

  def test_free_app_params_new_gallery_slack
    Marketplace::HelperMethods.stubs(:extension_details).returns(extension_details_map('slack_v2'))
    Marketplace::HelperMethods.stubs(:extension_name).returns('slack_v2')
    Marketplace::HelperMethods.stubs(:get_others_redis_key).returns('dummycache')
    Marketplace::HelperMethods.stubs(:remove_others_redis_key).returns(true)
    HelperMethodsTest.any_instance.stubs(:extension_name).returns('slack_v2')
    HelperMethodsTest.any_instance.stubs(:get_others_redis_key).returns('dummycache')
    HelperMethodsTest.any_instance.stubs(:remove_others_redis_key).returns(true)
    HelperMethodsTest.any_instance.stubs(:paid_app?).returns(false)
    Account.any_instance.stubs(:marketplace_gallery_enabled?).returns(true)
    params = paid_app_params
    assert_empty(params)
  ensure
    Account.any_instance.unstub(:marketplace_gallery_enabled?)
    Marketplace::HelperMethods.unstub(:extension_details)
    Marketplace::HelperMethods.unstub(:get_others_redis_key)
    Marketplace::HelperMethods.unstub(:remove_others_redis_key)
    Marketplace::HelperMethods.unstub(:extension_name)
    HelperMethodsTest.any_instance.unstub(:get_others_redis_key)
    HelperMethodsTest.any_instance.unstub(:remove_others_redis_key)
    HelperMethodsTest.any_instance.unstub(:extension_name)
    HelperMethodsTest.any_instance.unstub(:paid_app?)
  end

  def test_paid_app_params_new_gallery_custom
    Marketplace::HelperMethods.stubs(:extension_details).returns(extension_details_map('slack_v2'))
    Marketplace::HelperMethods.stubs(:extension_name).returns('slack_v2')
    Marketplace::HelperMethods.stubs(:get_others_redis_key).returns('dummycache')
    Marketplace::HelperMethods.stubs(:remove_others_redis_key).returns(true)
    HelperMethodsTest.any_instance.stubs(:extension_name).returns('slack_v2')
    HelperMethodsTest.any_instance.stubs(:get_others_redis_key).returns('dummycache')
    HelperMethodsTest.any_instance.stubs(:remove_others_redis_key).returns(true)
    HelperMethodsTest.any_instance.stubs(:paid_app?).returns(true)
    HelperMethodsTest.any_instance.stubs(:addon_details).returns('addon_id' => '1234')
    Account.any_instance.stubs(:marketplace_gallery_enabled?).returns(true)
    params = paid_app_params
    assert_equal(params[:billing][:addon_id], '1234')
  ensure
    Account.any_instance.unstub(:marketplace_gallery_enabled?)
    Marketplace::HelperMethods.unstub(:extension_details)
    Marketplace::HelperMethods.unstub(:get_others_redis_key)
    Marketplace::HelperMethods.unstub(:remove_others_redis_key)
    Marketplace::HelperMethods.unstub(:extension_name)
    HelperMethodsTest.any_instance.unstub(:get_others_redis_key)
    HelperMethodsTest.any_instance.unstub(:remove_others_redis_key)
    HelperMethodsTest.any_instance.unstub(:extension_name)
    HelperMethodsTest.any_instance.unstub(:paid_app?)
    HelperMethodsTest.any_instance.unstub(:addon_details)
  end
end
