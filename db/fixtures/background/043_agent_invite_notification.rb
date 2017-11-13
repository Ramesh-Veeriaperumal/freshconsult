account = Account.current

if account.freshid_enabled?
  EmailNotification.seed(:account_id, :notification_type) do |s|
    s.notification_type = EmailNotification::AGENT_INVITATION
    s.account_id = account.id
    s.requester_notification = false
    s.agent_notification = true
    s.agent_template = 'Hi {{agent.name}},<br /><br />
              Your {{helpdesk_name}} account has been created.<br /><br />
              Click <a href="{{helpdesk_url}}">here</a> to go to your account. <br /><br />
              If the above URL does not work, try copying and pasting it into your browser. Please feel free to contact us, if you continue to face any problems.<br /><br />
              Regards,<br />{{helpdesk_name}}'
    s.agent_subject_template = "{{portal_name}} agent invitation"
  end
end