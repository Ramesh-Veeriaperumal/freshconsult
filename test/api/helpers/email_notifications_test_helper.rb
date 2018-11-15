module EmailNotificationsTestHelper

  def unstub_email_notification_privilege
    User.any_instance.stubs(:privilege?).with(:manage_email_settings).returns(false)
    yield
    User.any_instance.unstub(:privilege?)
  end

  def email_notification_payload(params = {})
    {
      'requester_notification' => params[:requester_notification] || true,
      'requester_template' => params[:requester_template] || Faker::Lorem.characters(100),
      'requester_subject_template' => params[:requester_subject_template] || Faker::Lorem.characters(100),
      'agent_notification' => params[:agent_notification] || true,
      'agent_template' => params[:agent_template] || Faker::Lorem.characters(100),
      'agent_subject_template' => params[:agent_subject_template] || Faker::Lorem.characters(100)
    }
  end

  def show_email_notification_pattern(email_notifications)
    {
      'id' => email_notifications.notification_type,
      'requester_notification' => email_notifications.requester_notification,
      'requester_template' => email_notifications.requester_template,
      'requester_subject_template' => email_notifications.requester_subject_template,
      'agent_notification' => email_notifications.agent_notification,
      'agent_template' => email_notifications.agent_template,
      'agent_subject_template' => email_notifications.agent_subject_template
    }
  end

  def email_notification_requester_param(params = {})
    {
      'requester_notification' => true,
      'requester_template' => params[:requester_template] || Faker::Lorem.characters(100),
      'requester_subject_template' => params[:requester_subject_template] || Faker::Lorem.characters(100)
    }
  end

  def email_notification_only_requester_pattern(payload)
    payload.merge({
      'agent_notification' => false,
      'agent_template' => nil,
      'agent_subject_template' => nil
    })
  end

  def enable_bot_email_channel
    Account.current.stubs(:bot_email_channel_enabled?).returns(true)
    yield
  ensure
    Account.current.unstub(:bot_email_channel_enabled?)
  end
end