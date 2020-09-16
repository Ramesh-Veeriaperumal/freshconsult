require_relative '../../test_helper'

class Email::SettingsControllerTest < ActionController::TestCase
  include EmailSettingsTestHelper

  def wrap_cname(params)
    params
  end

  def test_successful_updation_of_all_features
    Redis.any_instance.stubs(:perform_redis_op).returns('OK')
    params = all_features_params
    put :update, params.merge(construct_params({ action: 'update', controller: 'email/settings' }, params))
    assert_response 200
    match_json(all_features_params)
  end

  def test_successful_updation_of_selected_features
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

  def test_update_with_invalid_feature_name
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

  def test_show_email_config_features
    Account.any_instance.stubs(:has_setting?).with(:reply_to_based_tickets).returns(true)
    Account.any_instance.stubs(:has_setting?).with(:disable_agent_forward).returns(false)
    Account.any_instance.stubs(:has_setting?).with(:compose_email).returns(false)
    Account.any_instance.stubs(:has_setting?).with(:personalized_email_replies).returns(true)
    get :show, controller_params
    assert_response 200
    match_json(all_features_params)
  ensure
    Account.any_instance.unstub(:has_feature?)
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
    params = all_features_params.except(:personalized_email_replies, :original_sender_as_requester_for_forward, :create_requester_using_reply_to)
    params[:allow_agent_to_initiate_conversation] = false
    Account.any_instance.stubs(:has_feature?).returns(false)
    put :update, construct_params({}, params)
    assert_response 200
    assert_equal(false, $redis_others.perform_redis_op('smembers', COMPOSE_EMAIL_ENABLED).include?(@account.id))
    params[:allow_agent_to_initiate_conversation] = true
    Account.any_instance.unstub(:has_feature?)
  end

  def teardown
    $redis_others.perform_redis_op('sadd', COMPOSE_EMAIL_ENABLED, @account.id)
  end
end
