account = Account.current

if account.freshid_integration_enabled?
  EmailNotification.seed(:account_id, :notification_type) do |s|
    s.notification_type = EmailNotification::AGENT_INVITATION
    s.account_id = account.id
    s.requester_notification = false
    s.agent_notification = true
    s.agent_template = EmailNotificationConstants::AGENT_INVITE_NOTIFICATION[:agent_template]
    s.agent_subject_template = EmailNotificationConstants::AGENT_INVITE_NOTIFICATION[:agent_subject_template]
  end
end