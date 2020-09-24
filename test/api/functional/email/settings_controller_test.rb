require_relative '../../test_helper'

class Email::SettingsControllerTest < ActionController::TestCase
  include EmailSettingsTestHelper

  def wrap_cname(params)
    params
  end

  def test_successful_updation_of_all_settings_with_email_new_settings_lp_enabled
    Account.current.launch(:email_new_settings)
    Redis.any_instance.stubs(:perform_redis_op).returns('OK')
    params = all_features_params
    put :update, params.merge(construct_params({ action: 'update', controller: 'email/settings' }, params))
    assert_response 200
    match_json(params)
  ensure
    Account.current.rollback(:email_new_settings)
  end

  # This can be removed after LP cleanup
  def test_successful_updation_of_settings_without_new_settings_with_email_new_settings_lp_disabled
    Redis.any_instance.stubs(:perform_redis_op).returns('OK')
    params = all_features_params.slice(*EmailSettingsConstants::UPDATE_FIELDS_WITHOUT_NEW_SETTINGS.map(&:to_sym))
    put :update, params.merge(construct_params({ action: 'update', controller: 'email/settings' }, params))
    assert_response 200
    match_json(params)
  end

  # This can be removed after LP cleanup
  def test_update_new_settings_with_email_new_settings_lp_disabled
    new_setting = (EmailSettingsConstants::UPDATE_FIELDS - EmailSettingsConstants::UPDATE_FIELDS_WITHOUT_NEW_SETTINGS)[0]
    params = { new_setting => true}
    put :update, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern(new_setting, :invalid_field, code: :invalid_field)])
  end

  def test_successful_updation_of_selected_settings_with_email_new_settings_lp_enabled
    Account.current.launch(:email_new_settings)
    params = all_features_params.except(:allow_agent_to_initiate_conversation, :original_sender_as_requester_for_forward)
    put :update, construct_params({}, params)
    assert_response 200
    match_json(all_features_params)
  ensure
    Account.current.rollback(:email_new_settings)
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

  # This can be removed after LP cleanup
  def test_show_email_config_features_with_email_new_settings_lp_disabled
    Account.current.rollback(:email_new_settings) if Account.current.skip_ticket_threading_enabled?
    Account.any_instance.stubs(:has_feature?).with(:reply_to_based_tickets).returns(true)
    Account.any_instance.stubs(:has_feature?).with(:disable_agent_forward).returns(false)
    Account.any_instance.stubs(:has_feature?).with(:compose_email).returns(false)
    Account.any_instance.stubs(:has_feature?).with(:personalized_email_replies).returns(true)
    get :show, controller_params
    assert_response 200
    match_json(all_features_params.slice(*EmailSettingsConstants::UPDATE_FIELDS_WITHOUT_NEW_SETTINGS.map(&:to_sym)))
  ensure
    Account.any_instance.unstub(:has_feature?)
  end

  def test_show_email_config_features_with_email_new_settings_lp_enabled
    Account.current.launch(:email_new_settings)
    Account.any_instance.stubs(:has_feature?).with(:reply_to_based_tickets).returns(true)
    Account.any_instance.stubs(:has_feature?).with(:disable_agent_forward).returns(false)
    Account.any_instance.stubs(:has_feature?).with(:compose_email).returns(false)
    Account.any_instance.stubs(:has_feature?).with(:personalized_email_replies).returns(true)
    Account.any_instance.stubs(:allow_wildcard_ticket_create_enabled?).returns(true)
    Account.any_instance.stubs(:skip_ticket_threading_enabled?).returns(true)
    get :show, controller_params
    assert_response 200
    match_json(all_features_params)
  ensure
    Account.any_instance.unstub(:has_feature?)
    Account.any_instance.unstub(:allow_wildcard_ticket_create_enabled?)
    Account.any_instance.unstub(:skip_ticket_threading_enabled?)
    Account.current.rollback(:email_new_settings)
  end

  def test_show_without_privilege
    User.any_instance.stubs(:privilege?).with(:manage_email_settings).returns(false)
    get :show, controller_params
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  ensure
    User.any_instance.unstub(:privilege?)
  end

  def test_update_redis_key_for_compose_email_feature
    Redis.any_instance.stubs(:perform_redis_op).returns([])
    params = { :allow_agent_to_initiate_conversation => false }
    Account.any_instance.stubs(:has_feature?).returns(false)
    put :update, construct_params({}, params)
    assert_response 200
    assert_equal(false, $redis_others.perform_redis_op('smembers', COMPOSE_EMAIL_ENABLED).include?(@account.id))
    params[:allow_agent_to_initiate_conversation] = true
    Account.any_instance.unstub(:has_feature?)
  end

  def test_update_new_setting_when_dependent_feature_disabled_with_email_new_settings_lp_enabled
    Account.current.launch(:email_new_settings)
    params = { allow_wildcard_ticket_create: true }
    dependent_feature = AccountSettings::SettingsConfig[:allow_wildcard_ticket_create][:feature_dependency]
    Account.any_instance.stubs(:has_feature?).with(dependent_feature).returns(false)
    put :update, construct_params({}, params)
    assert_response 403
    match_json(request_error_pattern(:require_feature, feature: :allow_wildcard_ticket_create.to_s))
  ensure
    Account.any_instance.unstub(:has_feature?)
    Account.current.rollback(:email_new_settings)
  end

  def teardown
    $redis_others.perform_redis_op('sadd', COMPOSE_EMAIL_ENABLED, @account.id)
  end
end
