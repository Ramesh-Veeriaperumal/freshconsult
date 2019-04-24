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

  def test_successful_updation_account_config_contact_info_and_invoice_email
    params = { email: 'test@me.com', first_name: 'me', last_name: 'you', phone: '283923911', invoice_emails: ['test@me.com'] }
    put :update, controller_params({ version: 'private' }.merge(wrap_cname(params)), false)
    assert_response 200
    match_json(account_admin_response(params))
  end

  def test_bad_request_on_not_permitted_params
    params = { email: 'test@me.com', first_name: 'me', last_name: 'you', phone: '283923911', extra: 'not permitted'}
    put :update, controller_params({ version: 'private' }.merge(wrap_cname(params)), false)
    assert_response 400
    match_json(account_admin_bad_request_error_patterns(:extra, 'Unexpected/invalid field in request', { code: "invalid_field" }))
  end

  def test_updation_failure_on_invoice_email_validation
    params = { email: 'test@me.com', first_name: 'me', last_name: 'you', phone: '283923911', invoice_emails: 'string value' }
    put :update, controller_params({ version: 'private' }.merge(wrap_cname(params)), false)
    assert_response 400
    match_json(account_admin_bad_request_error_patterns(:invoice_emails, 'Value set is of type String.It should be a/an Array', code: 'datatype_mismatch'))
  end

  def test_forbidden_access_without_manage_account_privilege
    remove_privilege(@agent, :manage_account)
    params = { email: 'test@me.com', first_name: 'me', last_name: 'you', phone: '283923911', invoice_emails: ['test@you.com'] }
    put :update, controller_params({ version: 'private' }.merge(wrap_cname(params)), false)
    assert_response 403
  ensure
    add_privilege(@agent, :manage_account)
  end

  def test_forbidden_access_without_manage_account_privilege_disable_billing_info_updation
    remove_privilege(@agent, :manage_account)
    put :disable_billing_info_updation, controller_params({ version: 'private' }, false)
    assert_response 403
  ensure
    add_privilege(@agent, :manage_account)
  end

  def test_successful_disable_billing_info_updation
    @account.launch(:update_billing_info)
    put :disable_billing_info_updation, controller_params({ version: 'private' }, false)
    assert_response 204
    assert_equal @account.launched?(:update_billing_info), false
  end

  def test_third_party_apps_not_called_for_anonymous_signup
    Account.any_instance.stubs(:anonymous_account?).returns(true)
    Account.any_instance.stubs(:sandbox?).returns(true)
    AccountConfiguration.any_instance.expects(:update_billing).never
    AccountConfiguration.any_instance.expects(:update_reseller_subscription).never
    AccountConfiguration.any_instance.expects(:update_crm_and_map).never
    params = { email: 'test@me.com', first_name: 'me', last_name: 'you', phone: '283923911', invoice_emails: ['test@me.com'] }
    put :update, controller_params({ version: 'private' }.merge(wrap_cname(params)), false)
  ensure
    Account.any_instance.unstub(:anonymous_account?)
    Account.any_instance.unstub(:sandbox?)
  end
end
