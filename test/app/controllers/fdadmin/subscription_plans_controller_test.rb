require_relative '../../../api/test_helper'
require Rails.root.join('spec', 'support', 'user_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class Fdadmin::SubscriptionPlansControllerTest < ActionController::TestCase
  def test_all_plans_success
    Fdadmin::DevopsMainController.stubs(:verify_signature).returns(nil)
    Fdadmin::DevopsMainController.stubs(:permit_internal_tools_ip).returns(nil)
    FreshopsSubdomains.stubs(:include?).returns(true)
    $redis_routes.stubs(:perform_redis_op).returns(true)
    OpenSSL::HMAC.stubs(:hexdigest).returns('xyz')
    params = { version: 'v1', digest: 'xyz' }
    get :all_plans, construct_params(params)
    assert_response 200
  ensure
    OpenSSL::HMAC.unstub(:hexdigest)
    $redis_routes.unstub(:perform_redis_op)
    FreshopsSubdomains.unstub(:include?)
    OpenSSL::HMAC.unstub(:hexdigest)
    Fdadmin::DevopsMainController.unstub(:verify_signature)
    Fdadmin::DevopsMainController.unstub(:permit_internal_tools_ip)
  end

  def test_all_plans_failure
    FreshopsSubdomains.stubs(:include?).returns(true)
    params = { version: 'v1', digest: 'xyz' }
    get :all_plans, construct_params(params)
    assert_response 401
  ensure
    Account.unstub(:current)
    OpenSSL::HMAC.unstub(:hexdigest)
    $redis_routes.unstub(:perform_redis_op)
    FreshopsSubdomains.unstub(:include?)
    OpenSSL::HMAC.unstub(:hexdigest)
    Fdadmin::DevopsMainController.unstub(:verify_signature)
    Fdadmin::DevopsMainController.unstub(:permit_internal_tools_ip)
  end
end
