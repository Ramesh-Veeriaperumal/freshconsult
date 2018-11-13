require_relative '../test_helper'
class AccountAdminsControllerTest < ActionController::TestCase
  include AccountAdminTestHelper
  include PrivilegesHelper

  def wrap_cname(params)
    { account_admin: params }
  end

  def setup
    super
    # below things done for not running chargeBee billing.
    AccountConfiguration.any_instance.stubs(:update_billing).returns(true)
  end

  def test_successful_updation_account_config_contact_info
    params = { email: 'test@me.com', first_name: 'me', last_name: 'you', phone: '283923911'}
    put :update, controller_params({ version: 'private'}.merge(wrap_cname(params)), false)
    assert_response 200
    match_json(account_admin_response(params))
  end

  def test_bad_request_on_not_permitted_params
    params = { email: 'test@me.com', first_name: 'me', last_name: 'you', phone: '283923911', extra: 'not permitted'}
    put :update, controller_params({ version: 'private'}.merge(wrap_cname(params)), false)
    assert_response 400
    match_json(account_admin_bad_request_error_patterns(:extra, 'Unexpected/invalid field in request', { code: "invalid_field" }))
  end

  def test_forbidden_access_without_manage_account_privilege
    remove_privilege(@agent, :manage_account)
    params = { email: 'test@me.com', first_name: 'me', last_name: 'you', phone: '283923911'}
    put :update, controller_params({ version: 'private'}.merge(wrap_cname(params)), false)
    assert_response 403
  ensure
    add_privilege(@agent, :manage_account)
  end
end
