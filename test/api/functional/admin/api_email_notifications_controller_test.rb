require_relative '../../test_helper'

class Admin::ApiEmailNotificationsControllerTest < ActionController::TestCase
  include EmailNotificationsTestHelper

  ###############UPDATE EMAIL NOTIFICATION##############
  def test_update_email_notifications
    email_notification_params = email_notification_payload
    put :update, construct_params(version: 'private', id: EmailNotification::NEW_TICKET, api_email_notification: email_notification_params)
    assert_response 200
    match_json(email_notification_params.merge('id': EmailNotification::NEW_TICKET))
  end

  def test_update_email_notifications_with_invalid_id
    email_notification_params = email_notification_payload
    put :update, construct_params(version: 'private', id: 0, api_email_notification: email_notification_params)
    assert_response 404
  end

  def test_update_email_notifications_without_privilege
    unstub_email_notification_privilege do
      email_notification_params = email_notification_payload
      put :update, construct_params(version: 'private', id: EmailNotification::NEW_TICKET, api_email_notification: email_notification_params)
      assert_response 403
    end
  end

   def test_update_email_notifications_with_empty_requester_template
    email_notification_params = email_notification_payload.merge(requester_template: "", requester_subject_template: "")
    put :update, construct_params(version: 'private', id: EmailNotification::NEW_TICKET, api_email_notification: email_notification_params)
    assert_response 400
    match_json([bad_request_error_pattern('requester_template', :"can't be blank", code: :invalid_value), 
      bad_request_error_pattern('requester_subject_template', :"can't be blank", code: :invalid_value)])
  end

  def test_update_email_notifications_with_empty_agent_template
    email_notification_params = email_notification_payload.merge(agent_template: "", agent_subject_template: "")
    put :update, construct_params(version: 'private', id: EmailNotification::NEW_TICKET, api_email_notification: email_notification_params)
    assert_response 400
    match_json([bad_request_error_pattern('agent_template', :"can't be blank", code: :invalid_value), 
      bad_request_error_pattern('agent_subject_template', :"can't be blank", code: :invalid_value)])
  end

  def test_update_bot_email_notification_1
    enable_bot_email_channel do
      email_notifications = Account.current.email_notifications.find_by_notification_type(EmailNotification::BOT_RESPONSE_TEMPLATE)
      assert_nil email_notifications
      email_notification_params = email_notification_requester_param
      put :update, construct_params(version: 'private', id: EmailNotification::BOT_RESPONSE_TEMPLATE, api_email_notification: email_notification_params)
      assert_response 200
      match_json(email_notification_only_requester_pattern(email_notification_params).merge('id': EmailNotification::BOT_RESPONSE_TEMPLATE))
      email_notifications = Account.current.email_notifications.find_by_notification_type(EmailNotification::BOT_RESPONSE_TEMPLATE)
      assert_not_nil email_notifications
    end
  end

  def test_update_bot_email_notification_2
    enable_bot_email_channel do
      email_notifications = Account.current.email_notifications.find_by_notification_type(EmailNotification::BOT_RESPONSE_TEMPLATE)
      assert_not_nil email_notifications
      email_notification_params = email_notification_requester_param
      put :update, construct_params(version: 'private', id: EmailNotification::BOT_RESPONSE_TEMPLATE, api_email_notification: email_notification_params)
      assert_response 200
      match_json(email_notification_only_requester_pattern(email_notification_params).merge('id': EmailNotification::BOT_RESPONSE_TEMPLATE))
    end
  end

  def test_update_show_bot_email_notification
    enable_bot_email_channel do
      email_notifications = Account.current.email_notifications.find_by_notification_type(EmailNotification::BOT_RESPONSE_TEMPLATE)
      assert_not_nil email_notifications
      email_notification_params = email_notification_requester_param
      put :update, construct_params(version: 'private', id: EmailNotification::BOT_RESPONSE_TEMPLATE, api_email_notification: email_notification_params)
      assert_response 200
      match_json(email_notification_only_requester_pattern(email_notification_params).merge('id': EmailNotification::BOT_RESPONSE_TEMPLATE))
      get :show, controller_params(version: 'private', id: EmailNotification::BOT_RESPONSE_TEMPLATE)
      assert_response 200
      email_notifications.reload
      match_json(show_email_notification_pattern(email_notifications))
    end
  end

  ###############SHOW EMAIL NOTIFICATION##############
  def test_show_email_notifications
    email_notifications = Account.current.email_notifications.find_by_notification_type(EmailNotification::NEW_TICKET)
    get :show, controller_params(version: 'private', id: EmailNotification::NEW_TICKET)
    assert_response 200
    match_json(show_email_notification_pattern(email_notifications))
  end

  def test_show_email_notifications_without_manage_email_settings_privilege
    unstub_email_notification_privilege do
      get :show, controller_params(version: 'private', id: EmailNotification::NEW_TICKET)
      assert_response 403
      match_json(request_error_pattern(:access_denied))
    end
  end

  def test_show_email_notifications_with_invalid_type
    get :show, controller_params(version: 'private', id: 0)
    assert_response 404
    assert_equal ' ', @response.body
  end

  def test_show_default_bot_email_notificaion
    enable_bot_email_channel do
      email_notifications = Account.current.email_notifications.find_by_notification_type(EmailNotification::BOT_RESPONSE_TEMPLATE)
      assert_nil email_notifications
      email_notifications = Account.current.default_bot_email_response
      get :show, controller_params(version: 'private', id: EmailNotification::BOT_RESPONSE_TEMPLATE)
      assert_response 200
      match_json(show_email_notification_pattern(email_notifications))
    end
  end
end