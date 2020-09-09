account = Account.current

EmailNotification.seed_many(:account_id, :notification_type, [
  {
    :notification_type => EmailNotification::USER_ACTIVATION, 
    :account_id => account.id, 
    :requester_notification => false, 
    :agent_notification => true,
    :agent_template => '<p>Hi {{agent.name}},<br /><br />You have been added as an agent in {{helpdesk_name}}.<br /><br />Click on the URL below to activate your account:<br /><br />{{activation_url}}<br /><br />If the URL does not work, try copying and pasting it into your browser. If you continue to have problems, please feel free to contact us.<br /><br />Regards,<br />{{helpdesk_name}}<br /><br />P.S. New to Freshdesk? Learn how to use the helpdesk by enrolling in the <a href="https://freshdesk.com/academy?utm_source=activation-email" target="_blank">Freshdesk Academy.</a></p>',
    :requester_template => '<p>Hi {{contact.name}},<br /><br />A new {{helpdesk_name}} account has been created for you.<br /><br />Click the url below to activate your account and select a password!<br /><br />{{activation_url}}<br /><br />If the above URL does not work try copying and pasting it into your browser. If you continue to have problems, please feel free to contact us.<br/><br/>Regards,<br/>{{helpdesk_name}}</p>',
    :requester_subject_template => "{{portal_name}} user activation",
    :agent_subject_template => "{{portal_name}} user activation"
  },
  {
    :notification_type => EmailNotification::PASSWORD_RESET,
    :account_id => account.id, 
    :requester_notification => true, 
    :agent_notification => !account.freshid_integration_enabled?,
    :agent_template => 'Hey {{agent.name}},<br /><br />
              A request to change your password has been made.<br /><br />
              To reset your password, click on the link below:<br />
              <a href="{{password_reset_url}}">Click here to reset the password.</a> <br /><br />
              If the above URL does not work, try copying and pasting it into your browser. Please feel free to contact us, if you continue to face any problems.<br /><br />
              Regards,<br />{{helpdesk_name}}',
    :requester_template => 'Hey {{contact.name}},<br /><br />
              A request to change your password has been made.<br /><br />
              To reset your password, click on the link below:<br />
              <a href="{{password_reset_url}}">Click here to reset the password.</a> <br /><br />
              If the above URL does not work, try copying and pasting it into your browser. Please feel free to contact us,if you continue to face any problems.<br /><br />
              Regards,<br />{{helpdesk_name}}',
    :requester_subject_template => "{{portal_name}} password reset instructions",
    :agent_subject_template => "{{portal_name}} password reset instructions"
  }
])