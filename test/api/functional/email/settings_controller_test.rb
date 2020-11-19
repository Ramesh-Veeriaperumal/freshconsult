require_relative '../../test_helper'

class Email::SettingsControllerTest < ActionController::TestCase
  include EmailSettingsTestHelper

  def setup
    super
    Account.any_instance.stubs(:auto_response_detector_enabled?).returns(true)
  end

  def teardown
    Account.any_instance.unstub(:auto_response_detector_enabled?)
  end

  def wrap_cname(params)
    params
  end

  def test_successful_updation_of_all_settings
    Account.current.launch(:email_new_settings)
    Account.current.launch(:threading_without_user_setting)
    Redis.any_instance.stubs(:perform_redis_op).returns('OK')
    params = all_features_params
    put :update, params.merge(construct_params({ action: 'update', controller: 'email/settings' }, params))
    assert_response 200
    match_json(params)
  ensure
    Account.current.rollback(:email_new_settings)
    Account.current.rollback(:threading_without_user_setting)
  end

  def test_successful_updation_of_selected_settings
    Account.current.launch(:email_new_settings)
    Account.current.launch(:threading_without_user_setting)
    params = all_features_params.except(:allow_agent_to_initiate_conversation, :original_sender_as_requester_for_forward)
    put :update, construct_params({}, params)
    assert_response 200
    match_json(all_features_params)
  ensure
    Account.current.rollback(:email_new_settings)
    Account.current.rollback(:threading_without_user_setting)
  end

  # This can be removed after LP cleanup
  def test_successful_updation_of_old_settings_without_feature
    Redis.any_instance.stubs(:perform_redis_op).returns('OK')
    params = all_features_params.slice(*EmailSettingsConstants::UPDATE_FIELDS_WITHOUT_NEW_SETTINGS.map(&:to_sym))
    put :update, params.merge(construct_params({ action: 'update', controller: 'email/settings' }, params))
    assert_response 200
    match_json(params)
  end

  # This can be removed after LP cleanup
  def test_update_new_settings_without_feature
    new_setting = (EmailSettingsConstants::UPDATE_FIELDS - EmailSettingsConstants::UPDATE_FIELDS_WITHOUT_NEW_SETTINGS)[0]
    params = { new_setting => true}
    put :update, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern(new_setting, :invalid_field, code: :invalid_field)])
  end

  def test_update_disable_agent_forward_and_compose_email_setting
    Account.any_instance.stubs(:compose_email_enabled?).returns(false)
    Account.any_instance.stubs(:disable_agent_forward_enabled?).returns(true)
    params = { allow_agent_to_initiate_conversation: true, original_sender_as_requester_for_forward: true }
    put :update, construct_params({}, params)
    refute Account.current.has_feature?(:disable_agent_forward)
    refute Account.current.has_feature?(:compose_email)
    Account.any_instance.stubs(:compose_email_enabled?).returns(true)
    Account.any_instance.stubs(:disable_agent_forward_enabled?).returns(false)
    params = { allow_agent_to_initiate_conversation: false, original_sender_as_requester_for_forward: false }
    put :update, construct_params({}, params)
    assert Account.current.has_feature?(:disable_agent_forward)
    assert Account.current.has_feature?(:compose_email)
  ensure
    Account.any_instance.unstub(:compose_email_enabled?)
    Account.any_instance.unstub(:disable_agent_forward_enabled?)
  end

  def test_update_with_invalid_value
    params = { 'personalized_email_replies': 'invalid_value' }
    put :update, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('personalized_email_replies', 'Value set is of type String.It should be a/an Boolean', code: :datatype_mismatch)])
  end

  def test_update_with_invalid_setting_name
    params = invalid_field_params
    put :update, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('invalid_field', :invalid_field, code: :invalid_field)])
  end

  def test_update_without_manage_email_settings_privileg_email_new_settings_lp_enabled
    Account.current.launch(:email_new_settings)
    params = all_features_params
    User.any_instance.stubs(:privilege?).with(:manage_email_settings).returns(false)
    put :update, construct_params({}, params)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  ensure
    User.any_instance.unstub(:privilege?)
    Account.current.rollback(:email_new_settings)
  end

  def test_update_redis_key_for_compose_email_setting
    Redis.any_instance.stubs(:perform_redis_op).returns([])
    params = { allow_agent_to_initiate_conversation: false }
    Account.any_instance.stubs(:compose_email_enabled?).returns(true)
    put :update, construct_params({}, params)
    assert_response 200
    assert_equal(false, $redis_others.perform_redis_op('smembers', COMPOSE_EMAIL_ENABLED).include?(@account.id))
    params[:allow_agent_to_initiate_conversation] = true
    Account.any_instance.unstub(:compose_email_enabled?)
  end

  def test_update_setting_when_dependent_feature_disabled
    params = { personalized_email_replies: true }
    dependent_feature = AccountSettings::SettingsConfig[:personalized_email_replies][:feature_dependency]
    Account.any_instance.stubs(:has_feature?).with(dependent_feature).returns(false)
    put :update, construct_params({}, params)
    assert_response 403
    match_json(request_error_pattern(:require_feature, feature: params.keys.first))
  ensure
    Account.any_instance.unstub(:has_feature?)
  end

  def test_update_with_invalid_value_for_threading_without_user_check
    Account.current.launch(:threading_without_user_setting)
    params = { 'threading_without_user_check': 'invalid_value' }
    put :update, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('threading_without_user_check', 'Value set is of type String.It should be a/an Boolean', code: :datatype_mismatch)])
  ensure
    Account.current.rollback(:threading_without_user_setting)
  end

  def test_update_threading_without_user_check_when_dependent_feature_disabled
    Account.current.launch(:threading_without_user_setting)
    params = { threading_without_user_check: true }
    dependent_feature = AccountSettings::SettingsConfig[:threading_without_user_check][:feature_dependency]
    Account.any_instance.stubs(:has_feature?).with(dependent_feature).returns(false)
    put :update, construct_params({}, params)
    assert_response 403
    match_json(request_error_pattern(:require_feature, feature: params.keys.first))
  ensure
    Account.any_instance.unstub(:has_feature?)
    Account.current.rollback(:threading_without_user_setting)
  end

  def test_show_email_settings
    Account.current.launch(:email_new_settings)
    Account.current.launch(:threading_without_user_setting)
    Account.any_instance.stubs(:reply_to_based_tickets_enabled?).returns(true)
    Account.any_instance.stubs(:disable_agent_forward_enabled?).returns(false)
    Account.any_instance.stubs(:compose_email_enabled?).returns(true)
    Account.any_instance.stubs(:personalized_email_replies_enabled?).returns(true)
    Account.any_instance.stubs(:allow_wildcard_ticket_create_enabled?).returns(true)
    Account.any_instance.stubs(:skip_ticket_threading_enabled?).returns(true)
    Account.any_instance.stubs(:threading_without_user_check_enabled?).returns(true)
    Account.any_instance.stubs(:auto_response_detector_enabled?).returns(true)
    Account.any_instance.stubs(:auto_response_detector_toggle_enabled?).returns(true)
    get :show, controller_params
    assert_response 200
    match_json(all_features_params)
  ensure
    Account.any_instance.unstub(:reply_to_based_tickets_enabled?)
    Account.any_instance.unstub(:disable_agent_forward_enabled?)
    Account.any_instance.unstub(:compose_email_enabled?)
    Account.any_instance.unstub(:personalized_email_replies_enabled?)
    Account.any_instance.unstub(:allow_wildcard_ticket_create_enabled?)
    Account.any_instance.unstub(:skip_ticket_threading_enabled?)
    Account.any_instance.unstub(:threading_without_user_check_enabled?)
    Account.current.rollback(:email_new_settings)
    Account.current.launch(:threading_without_user_setting)
    Account.any_instance.unstub(:auto_response_detector_enabled?)
    Account.any_instance.unstub(:auto_response_detector_toggle_enabled?)
  end

  # This can be removed after LP cleanup
  def test_show_email_settings_without_feature
    Account.current.rollback(:email_new_settings) if Account.current.email_new_settings_enabled?
    Account.current.rollback(:threading_without_user_setting)
    Account.any_instance.stubs(:reply_to_based_tickets_enabled?).returns(true)
    Account.any_instance.stubs(:disable_agent_forward_enabled?).returns(false)
    Account.any_instance.stubs(:compose_email_enabled?).returns(true)
    Account.any_instance.stubs(:personalized_email_replies_enabled?).returns(true)
    Account.any_instance.stubs(:auto_response_detector_enabled?).returns(true)
    Account.any_instance.stubs(:auto_response_detector_toggle_enabled?).returns(true)

    get :show, controller_params
    assert_response 200
    match_json(all_features_params.slice(*EmailSettingsConstants::UPDATE_FIELDS_WITHOUT_NEW_SETTINGS.map(&:to_sym)))
  ensure
    Account.any_instance.unstub(:reply_to_based_tickets_enabled?)
    Account.any_instance.unstub(:disable_agent_forward_enabled?)
    Account.any_instance.unstub(:compose_email_enabled?)
    Account.any_instance.unstub(:personalized_email_replies_enabled?)
    Account.any_instance.unstub(:auto_response_detector_enabled?)
    Account.any_instance.unstub(:auto_response_detector_toggle_enabled?)
  end

  def test_show_auto_response_detector_toggle_not_available_if_plan_feature_not_enabled
    Account.any_instance.stubs(:auto_response_detector_enabled?).returns(false)
    get :show, controller_params
    assert_response 200
    response_body = JSON.parse(response.body)
    assert_equal response_body.key?('auto_response_detector_toggle'), false
  ensure
    Account.any_instance.unstub(:auto_response_detector_enabled?)
  end

  def test_show_auto_response_detector_toggle_is_available_if_plan_feature_enabled
    get :show, controller_params
    assert_response 200
    response_body = JSON.parse(response.body)
    assert_equal response_body['auto_response_detector_toggle'], false
  end

  def test_update_with_auto_response_detector_toggle_throw_bad_request_if_plan_feature_not_enabled
    Account.any_instance.stubs(:auto_response_detector_enabled?).returns(false)
    params = { auto_response_detector_toggle: false }
    put :update, construct_params({}, params)
    assert_response 403
    match_json(request_error_pattern(:require_feature, feature: params.keys.first))
  ensure
    Account.any_instance.unstub(:auto_response_detector_enabled?)
  end

  def test_successful_update_with_auto_response_detector_toggle_if_plan_feature_enabled
    params = { auto_response_detector_toggle: true }
    put :update, construct_params({}, params)
    assert_response 200
    response_body = JSON.parse(response.body)
    assert_equal response_body['auto_response_detector_toggle'], true
    assert_equal Account.current.auto_response_detector_toggle_enabled?, true

    params = { auto_response_detector_toggle: false }
    put :update, construct_params({}, params)
    assert_response 200
    response_body = JSON.parse(response.body)
    assert_equal response_body['auto_response_detector_toggle'], false
    assert_equal Account.current.auto_response_detector_toggle_enabled?, false
  end

  def test_show_auto_response_detector_toggle_not_available_if_plan_feature_not_enabled
    Account.any_instance.stubs(:auto_response_detector_enabled?).returns(false)
    get :show, controller_params
    assert_response 200
    response_body = JSON.parse(response.body)
    assert_equal response_body.key?('auto_response_detector_toggle'), false
  ensure
    Account.any_instance.unstub(:auto_response_detector_enabled?)
  end

  def test_show_auto_response_detector_toggle_is_available_if_plan_feature_enabled
    get :show, controller_params
    assert_response 200
    response_body = JSON.parse(response.body)
    assert_equal response_body['auto_response_detector_toggle'], false
  end

  def test_update_with_auto_response_detector_toggle_throw_bad_request_if_plan_feature_not_enabled
    Account.any_instance.stubs(:auto_response_detector_enabled?).returns(false)
    params = { auto_response_detector_toggle: false }
    put :update, construct_params({}, params)
    assert_response 403
    match_json(request_error_pattern(:require_feature, feature: params.keys.first))
  ensure
    Account.any_instance.unstub(:auto_response_detector_enabled?)
  end

  def test_successful_update_with_auto_response_detector_toggle_if_plan_feature_enabled
    params = { auto_response_detector_toggle: true }
    put :update, construct_params({}, params)
    assert_response 200
    response_body = JSON.parse(response.body)
    assert_equal response_body['auto_response_detector_toggle'], true
    assert_equal Account.current.auto_response_detector_toggle_enabled?, true

    params = { auto_response_detector_toggle: false }
    put :update, construct_params({}, params)
    assert_response 200
    response_body = JSON.parse(response.body)
    assert_equal response_body['auto_response_detector_toggle'], false
    assert_equal Account.current.auto_response_detector_toggle_enabled?, false
  end

  def test_show_without_privilege
    User.any_instance.stubs(:privilege?).with(:manage_email_settings).returns(false)
    get :show, controller_params
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  ensure
    User.any_instance.unstub(:privilege?)
  end

  def teardown
    $redis_others.perform_redis_op('sadd', COMPOSE_EMAIL_ENABLED, @account.id)
  end
end
