require_relative '../../test_helper'

class Email::SettingsControllerTest < ActionController::TestCase
  include EmailSettingsTestHelper

  def wrap_cname(params)
    params
  end

  def test_successful_updation_of_all_settings
    Redis.any_instance.stubs(:perform_redis_op).returns('OK')
    params = all_features_params
    put :update, params.merge(construct_params({ action: 'update', controller: 'email/settings' }, params))
    assert_response 200
    match_json(all_features_params)
  end

  def test_update_disable_agent_forward_and_compose_email_setting
    Account.any_instance.stubs(:compose_email_enabled?).returns(false)
    Account.any_instance.stubs(:disable_agent_forward_enabled?).returns(true)
    params = { allow_agent_to_initiate_conversation: true, original_sender_as_requester_for_forward: true }
    put :update, construct_params({}, params)
    refute Account.current.has_feature?(:disable_agent_forward)
    assert Account.current.has_feature?(:compose_email)
    Account.any_instance.stubs(:compose_email_enabled?).returns(true)
    Account.any_instance.stubs(:disable_agent_forward_enabled?).returns(false)
    params = { allow_agent_to_initiate_conversation: false, original_sender_as_requester_for_forward: false }
    put :update, construct_params({}, params)
    assert Account.current.has_feature?(:disable_agent_forward)
    refute Account.current.has_feature?(:compose_email)
  ensure
    Account.any_instance.unstub(:compose_email_enabled?)
    Account.any_instance.unstub(:disable_agent_forward_enabled?)
  end

  def test_successful_updation_of_selected_settings
    params = all_features_params.except(:allow_agent_to_initiate_conversation, :original_sender_as_requester_for_forward)
    put :update, construct_params({}, params)
    assert_response 200
    match_json(all_features_params)
  end

  def test_update_with_invalid_value
    params = all_features_params.except(:allow_agent_to_initiate_conversation, :original_sender_as_requester_for_forward, :create_requester_using_reply_to)
    params[:personalized_email_replies] = 'invalid_value'
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

  def test_update_without_manage_email_settings_privilege
    params = all_features_params
    User.any_instance.stubs(:privilege?).with(:manage_email_settings).returns(false)
    put :update, construct_params({}, params)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  ensure
    User.any_instance.unstub(:privilege?)
  end

  def test_show_email_config_settings
    Account.any_instance.stubs(:reply_to_based_tickets_enabled?).returns(true)
    Account.any_instance.stubs(:disable_agent_forward_enabled?).returns(false)
    Account.any_instance.stubs(:compose_email_enabled?).returns(true)
    Account.any_instance.stubs(:personalized_email_replies_enabled?).returns(true)
    get :show, controller_params
    assert_response 200
    match_json(all_features_params)
  ensure
    Account.any_instance.unstub(:reply_to_based_tickets_enabled?)
    Account.any_instance.unstub(:disable_agent_forward_enabled?)
    Account.any_instance.unstub(:compose_email_enabled?)
    Account.any_instance.unstub(:personalized_email_replies_enabled?)
  end

  def test_show_without_privilege
    User.any_instance.stubs(:privilege?).with(:manage_email_settings).returns(false)
    get :show, controller_params
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  ensure
    User.any_instance.unstub(:privilege?)
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
    params = { EmailSettingsConstants::UPDATE_FIELDS.sample => true }
    setting_name = EmailSettingsConstants::EMAIL_SETTINGS_PARAMS_MAPPING[params.keys.first.to_sym] || params.keys.first.to_sym
    dependent_feature = AccountSettings::SettingsConfig[setting_name][:feature_dependency]
    Account.any_instance.stubs(:has_feature?).with(dependent_feature).returns(false)
    put :update, construct_params({}, params)
    assert_response 403
    match_json(request_error_pattern(:require_feature, feature: params.keys.first))
  ensure
    Account.any_instance.unstub(:has_feature?)
  end

  def teardown
    $redis_others.perform_redis_op('sadd', COMPOSE_EMAIL_ENABLED, @account.id)
  end
end
