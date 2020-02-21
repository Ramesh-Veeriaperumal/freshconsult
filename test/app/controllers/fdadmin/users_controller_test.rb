require_relative '../../../api/test_helper'
require Rails.root.join('spec', 'support', 'user_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class Fdadmin::UsersControllerTest < ActionController::TestCase
  def setup
    super
    before_all
  end

  def before_all
    @account = Account.first.make_current
    @user = @account.agents.first.user
  end

  def test_user_detail_with_id
    Account.stubs(:current).returns(@account)
    Fdadmin::DevopsMainController.stubs(:verify_signature).returns(nil)
    Fdadmin::DevopsMainController.stubs(:permit_internal_tools_ip).returns(nil)
    FreshopsSubdomains.stubs(:include?).returns(true)
    $redis_routes.stubs(:perform_redis_op).returns(true)
    OpenSSL::HMAC.stubs(:hexdigest).returns('xyz')
    account_id = @account.id
    user_id = @user.id
    params = { version: 'v1', account_id: account_id, digest: 'xyz', user_id: user_id }
    get :get_user, construct_params(params)
    assert_response 200
  ensure
    Account.unstub(:current)
    OpenSSL::HMAC.unstub(:hexdigest)
    $redis_routes.unstub(:perform_redis_op)
    FreshopsSubdomains.unstub(:include?)
    OpenSSL::HMAC.unstub(:hexdigest)
    Fdadmin::DevopsMainController.unstub(:verify_signature)
    Fdadmin::DevopsMainController.unstub(:permit_internal_tools_ip)
  end

  def test_user_detail_with_email
    Account.stubs(:current).returns(@account)
    Fdadmin::DevopsMainController.stubs(:verify_signature).returns(nil)
    Fdadmin::DevopsMainController.stubs(:permit_internal_tools_ip).returns(nil)
    FreshopsSubdomains.stubs(:include?).returns(true)
    $redis_routes.stubs(:perform_redis_op).returns(true)
    OpenSSL::HMAC.stubs(:hexdigest).returns('xyz')
    account_id = @account.id
    user_email = @user.email
    params = { version: 'v1', account_id: account_id, digest: 'xyz', email: user_email }
    get :get_user, construct_params(params)
    assert_response 200
  ensure
    Account.unstub(:current)
    OpenSSL::HMAC.unstub(:hexdigest)
    $redis_routes.unstub(:perform_redis_op)
    FreshopsSubdomains.unstub(:include?)
    OpenSSL::HMAC.unstub(:hexdigest)
    Fdadmin::DevopsMainController.unstub(:verify_signature)
    Fdadmin::DevopsMainController.unstub(:permit_internal_tools_ip)
  end

  def test_user_detail_with_freshid
    Account.stubs(:current).returns(@account)
    Fdadmin::DevopsMainController.stubs(:verify_signature).returns(nil)
    Fdadmin::DevopsMainController.stubs(:permit_internal_tools_ip).returns(nil)
    FreshopsSubdomains.stubs(:include?).returns(true)
    $redis_routes.stubs(:perform_redis_op).returns(true)
    OpenSSL::HMAC.stubs(:hexdigest).returns('xyz')
    account_id = @account.id
    user_id = @user.id
    FreshopsSubdomains.stubs(:include?).returns(true)
    $redis_routes.stubs(:perform_redis_op).returns(true)
    params = { version: 'v1', account_id: account_id, digest: 'xyz', uuid: user_id }
    get :get_user, construct_params(params)
    assert_response 200
  ensure
    Account.unstub(:current)
    OpenSSL::HMAC.unstub(:hexdigest)
    $redis_routes.unstub(:perform_redis_op)
    FreshopsSubdomains.unstub(:include?)
    OpenSSL::HMAC.unstub(:hexdigest)
    Fdadmin::DevopsMainController.unstub(:verify_signature)
    Fdadmin::DevopsMainController.unstub(:permit_internal_tools_ip)
  end

  def test_user_detail_with_invalid_token
    Account.stubs(:current).returns(@account)
    account_id = @account.id
    user_id = @user.id
    params = { version: 'v1', account_id: account_id, digest: 'xyz', user_id: user_id }
    get :get_user, construct_params(params)
    assert_response 401
  ensure
    Account.unstub(:current)
    Fdadmin::DevopsMainController.unstub(:verify_signature)
    Fdadmin::DevopsMainController.unstub(:permit_internal_tools_ip)
  end
end
