require_relative '../test_helper'
class AccountAdminsControllerTest < ActionController::TestCase
  include AccountAdminTestHelper
  include PrivilegesHelper
  include Redis::HashMethods
  include AccountConstants

  def wrap_cname(params)
    { account_admin: params }
  end

  def setup
    super
    # below things done for not running chargeBee billing.
    AccountConfiguration.any_instance.stubs(:update_billing).returns(true)
  end

  def test_successful_updation_account_config_contact_info_and_invoice_email
    company_name = Faker::Lorem.characters(6)
    params = { email: 'test@me.com', first_name: 'me', last_name: 'you', phone: '283923911', invoice_emails: ['test@me.com'], company_name: company_name }
    put :update, controller_params({ version: 'private' }.merge(wrap_cname(params)), false)
    assert_response 200
    assert_equal @account.helpdesk_name, company_name
    match_json(account_admin_response(params))
  end

  def test_bad_request_on_not_permitted_params
    params = { email: 'test@me.com', first_name: 'me', last_name: 'you', phone: '283923911', extra: 'not permitted' }
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

  def test_preferences_get
    additional_settings = @account.account_additional_settings.additional_settings
    get :preferences, controller_params
    assert_response 200
    match_json(preferences_response(additional_settings)) if additional_settings.key? :skip_mandatory_checks
  end

  def test_preferences_get_with_account_additional_redis_hash
    additional_settings = @account.account_additional_settings.additional_settings
    # Set account settings redis hash key
    account_setting_redis_key = format(ACCOUNT_SETTINGS_REDIS_HASH, account_id: @account.id)
    set_key_in_redis_hash(account_setting_redis_key, 'omni_phone_error_report', true)
    additional_settings_with_redis = multi_get_all_redis_hash(account_setting_redis_key).reverse_merge!(additional_settings)
    get :preferences, controller_params
    assert_response 200
    match_json(additional_settings_with_redis)
  end

  def test_preferences_get_default_refresh_value_with_omni_agent_availability_dashboard_feature
    Account.any_instance.stubs(:omni_agent_availability_dashboard_enabled?).returns(true)
    additional_settings = @account.account_additional_settings.additional_settings
    account_setting_redis_key = format(ACCOUNT_SETTINGS_REDIS_HASH, account_id: @account.id)
    set_key_in_redis_hash(account_setting_redis_key, 'omni_phone_error_report', true)
    additional_settings[:agent_availability_refresh_time] = DEFAULT_AGENT_AVAILABILITY_REFRESH_TIME
    additional_settings_with_redis = multi_get_all_redis_hash(account_setting_redis_key).reverse_merge!(additional_settings)
    get :preferences, controller_params
    assert_response 200
    match_json(additional_settings_with_redis)
  ensure
    Account.any_instance.unstub(:omni_agent_availability_dashboard_enabled?)
  end

  def test_preferences_get_custom_refresh_value_with_omni_agent_availability_dashboard_feature
    Account.any_instance.stubs(:omni_agent_availability_dashboard_enabled?).returns(true)
    additional_settings = @account.account_additional_settings.additional_settings
    additional_settings[:agent_availability_refresh_time] = 30
    @account.account_additional_settings.save!
    account_setting_redis_key = format(ACCOUNT_SETTINGS_REDIS_HASH, account_id: @account.id)
    set_key_in_redis_hash(account_setting_redis_key, 'omni_phone_error_report', true)
    additional_settings_with_redis = multi_get_all_redis_hash(account_setting_redis_key).reverse_merge!(additional_settings)
    get :preferences, controller_params
    assert_response 200
    match_json(additional_settings_with_redis)
  ensure
    Account.any_instance.unstub(:omni_agent_availability_dashboard_enabled?)
  end

  def test_forbidden_access_without_manage_account_privilege_preferences_set
    remove_privilege(@agent, :manage_account)
    put :preferences=, controller_params
    assert_response 403
  ensure
    add_privilege(@agent, :manage_account)
  end

  def test_bad_request_preferences_set
    put :preferences=, construct_params('skip_mandatory_checks' => 'invalid')
    assert_response 400
    match_json(account_admin_bad_request_error_patterns(:skip_mandatory_checks, 'Value set is of type String.It should be a/an Boolean', code: 'datatype_mismatch'))
  end

  def test_successful_preferences_set
    put :preferences=, construct_params('skip_mandatory_checks' => true)
    assert_response 204
    assert_equal @account.account_additional_settings.additional_settings[:skip_mandatory_checks], true
  end

  def test_third_party_apps_not_called_for_anonymous_signup
    Account.any_instance.stubs(:anonymous_account?).returns(true)
    Account.any_instance.stubs(:sandbox?).returns(true)
    AccountConfiguration.any_instance.stubs(:anonymous_account?).returns(true)
    AccountConfiguration.any_instance.expects(:update_billing).never
    AccountConfiguration.any_instance.expects(:update_reseller_subscription).never
    AccountConfiguration.any_instance.expects(:update_crm_and_map).never
    params = { email: 'test@me.com', first_name: 'me', last_name: 'you', phone: '283923911', invoice_emails: ['test@me.com'] }
    put :update, controller_params({ version: 'private' }.merge(wrap_cname(params)), false)
  ensure
    Account.any_instance.unstub(:anonymous_account?)
    Account.any_instance.unstub(:sandbox?)
    AccountConfiguration.any_instance.unstub(:anonymous_account?)
  end

  def test_feedback_widget_set_captcha_disabled
    Account.current.launch(:still_enable_captcha)
    post :preferences=, construct_params(feedback_widget: { disable_captcha: true })
    assert_response 204
    @account.reload
    refute @account.feedback_widget_captcha_allowed?
  ensure
    Account.current.rollback(:still_enable_captcha)
  end

  def test_feedback_widget_set_captcha_enabled
    Account.current.launch(:still_enable_captcha)
    put :preferences=, construct_params(feedback_widget: { disable_captcha: false })
    assert_response 204
    @account.reload
    assert @account.feedback_widget_captcha_allowed?
  ensure
    Account.current.rollback(:still_enable_captcha)
  end

  def test_feedback_widget_set_captcha_wrong_params
    post :preferences=, construct_params(feedback_widget: { enable_captcha: true })
    assert_response 400
    match_json(account_admin_bad_request_error_patterns(:enable_captcha, 'Unexpected/invalid field in request', code: :invalid_field))
  end

  def test_feedback_widget_set_captcha_wrong_param_type
    post :preferences=, construct_params(feedback_widget: { disable_captcha: 'true' })
    assert_response 400
    match_json([bad_request_error_pattern_with_nested_field('feedback_widget', 'disable_captcha', 'It should be a/an Boolean', code: :datatype_mismatch)])
  end

  def test_preference_get_with_manage_availability_privilege_with_default_value
    Account.any_instance.stubs(:omni_agent_availability_dashboard_enabled?).returns(true)
    additional_settings = @account.account_additional_settings.additional_settings
    account_settings_redis_hash = set_preferences_in_redis
    remove_privilege(@agent, :manage_account)
    add_privilege(@agent, :manage_availability)
    get :preferences, controller_params
    assert_response 200
    match_json(restricted_preferences_response(account_settings_redis_hash, additional_settings))
  ensure
    remove_privilege(@agent, :manage_availability)
    add_privilege(@agent, :manage_account)
    Account.any_instance.unstub(:omni_agent_availability_dashboard_enabled?)
  end

  def test_preference_get_with_manage_availability_privilege
    Account.any_instance.stubs(:omni_agent_availability_dashboard_enabled?).returns(true)
    additional_settings = @account.account_additional_settings.additional_settings
    additional_settings[:agent_availability_refresh_time] = 30
    @account.account_additional_settings.save!
    account_settings_redis_hash = set_preferences_in_redis
    remove_privilege(@agent, :manage_account)
    add_privilege(@agent, :manage_availability)
    get :preferences, controller_params
    assert_response 200
    match_json(restricted_preferences_response(account_settings_redis_hash, additional_settings))
  ensure
    remove_privilege(@agent, :manage_availability)
    add_privilege(@agent, :manage_account)
    Account.any_instance.unstub(:omni_agent_availability_dashboard_enabled?)
  end

  def test_preference_get_with_manage_availability_privilege_without_feature
    Account.any_instance.stubs(:omni_agent_availability_dashboard_enabled?).returns(false)
    additional_settings = @account.account_additional_settings.additional_settings
    account_settings_redis_hash = set_preferences_in_redis
    remove_privilege(@agent, :manage_account)
    add_privilege(@agent, :manage_availability)
    get :preferences, controller_params
    assert_response 200
    match_json(restricted_preferences_response(account_settings_redis_hash, additional_settings))
  ensure
    remove_privilege(@agent, :manage_availability)
    add_privilege(@agent, :manage_account)
    Account.any_instance.unstub(:omni_agent_availability_dashboard_enabled?)
  end

  def test_preference_get_for_agents
    Account.any_instance.stubs(:omni_agent_availability_dashboard_enabled?).returns(true)
    account_settings_redis_hash = set_preferences_in_redis
    remove_privilege(@agent, :manage_availability)
    remove_privilege(@agent, :manage_account)
    get :preferences, controller_params
    assert_response 200
    match_json(account_settings_redis_hash)
  ensure
    add_privilege(@agent, :manage_account)
    Account.any_instance.unstub(:omni_agent_availability_dashboard_enabled?)
  end

  private

    def set_preferences_in_redis
      account_setting_redis_key = format(ACCOUNT_SETTINGS_REDIS_HASH, account_id: @account.id)
      set_key_in_redis_hash(account_setting_redis_key, 'omni_phone_error_report', true)
      multi_get_all_redis_hash(account_setting_redis_key)
    end
end
