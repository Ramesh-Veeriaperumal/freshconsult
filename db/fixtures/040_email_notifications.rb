account = Account.current

EmailNotification.seed_many(:account_id, :notification_type, [
  {
    :notification_type => EmailNotification::USER_ACTIVATION, 
    :account_id => account.id, 
    :requester_notification => true, 
    :agent_notification => true,
    :agent_template => '<p>Hi {{agent.name}},<br /><br />Your {{helpdesk_name}} account has been created.<br /><br />Click the url below to activate your account!<br /><br />{{activation_url}}<br /><br />If the above URL does not work try copying and pasting it into your browser. If you continue to have problems, please feel free to contact us.<br /><br />Regards,<br />{{helpdesk_name}}</p>',
    :requester_template => '<p>Hi {{contact.name}},<br /><br />A new {{helpdesk_name}} account has been created for you.<br /><br />Click the url below to activate your account and select a password!<br /><br />{{activation_url}}<br /><br />If the above URL does not work try copying and pasting it into your browser. If you continue to have problems, please feel free to contact us.<br/><br/>Regards,<br/>{{helpdesk_name}}</p>',
    :requester_subject_template => "{{portal_name}} user activation",
    :agent_subject_template => "{{portal_name}} user activation"
  },
  {
    :notification_type => EmailNotification::PASSWORD_RESET,
    :account_id => account.id, 
    :requester_notification => true, 
    :agent_notification => true,
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
  },
  { 
    :notification_type => EmailNotification::NEW_TICKET, 
    :account_id => account.id, :requester_notification => true, 
    :agent_notification => false,
    :agent_template => '<p>Hi,<br /><br />A new ticket has been created. <br />You may view and respond to the ticket here {{ticket.url}}<br /><br />Regards,<br />{{helpdesk_name}}</p>',
    :requester_template => '<p>Dear {{ticket.requester.name}},<br /><br />We would like to acknowledge that we have received your request and a ticket has been created.<br />A support representative will be reviewing your request and will send you a personal response.(usually within 24 hours).<br /><br />To view the status of the ticket or add comments, please visit <br />{{ticket.url}}<br /><br />Thank you for your patience.<br /><br />Sincerely,<br />{{helpdesk_name}} Support Team</p>',
    :requester_subject_template => "Ticket Received - {{ticket.subject}}",
    :agent_subject_template => "New ticket has been created - {{ticket.subject}}"
  },
  { :notification_type => EmailNotification::TICKET_ASSIGNED_TO_GROUP, 
      :account_id => account.id, :requester_notification => false, 
      :agent_notification => true,
      :agent_template => '<p>Hi<br /><br />A new ticket has been assigned to your group "{{ticket.group.name}}". Please follow the link below to view the ticket.<br /><br />{{ticket.subject}}<br />{{ticket.description}}<br />{{ticket.url}}</p>',
    :agent_subject_template => "Assigned to Group - {{ticket.subject}}"
},
  {
    :notification_type => EmailNotification::TICKET_UNATTENDED_IN_GROUP, 
    :account_id => account.id, 
    :requester_notification => false, 
    :agent_notification => true,
    :agent_template => '<p>Hi {{agent.name}},<br /><br />A new ticket in group {{ticket.group.name}} is currently unassigned for more than {{ticket.group.assign_time_mins}} minutes.<br /><br />Ticket Details: <br /><br />Subject - {{ticket.subject}}<br /><br />Description  - {{ticket.description}}<br /><br />This is an escalation email for the {{ticket.group.name}} group in {{helpdesk_name}}<br />{{ticket.url}}</p>',
    :agent_subject_template => "Unattended ticket - {{ticket.subject}}"
  },
  { :notification_type => EmailNotification::TICKET_ASSIGNED_TO_AGENT, 
      :account_id => account.id, :requester_notification => false, 
      :agent_notification => true,
      :agent_template => '<p>Hi {{ticket.agent.name}},<br /><br />A new ticket has been assigned to you. Please follow the link below to view the ticket.<br /><br />{{ticket.subject}}<br />{{ticket.description}}<br />{{ticket.url}}</p>',
    :agent_subject_template => "Ticket Assigned - {{ticket.subject}}"
},
  { :notification_type => EmailNotification::COMMENTED_BY_AGENT, 
      :account_id => account.id, :requester_notification => true, 
      :agent_notification => false,
      :requester_template => '<p>Dear {{ticket.requester.name}},<br/>There is a new comment on your ticket. You can view your ticket by visiting {{ticket.url}}<br />You can also reply to this email to add your comment.<br/>Ticket comment <br />{{comment.commenter.name}} &#8211; {{comment.body}}<br/>Sincerely,<br />{{helpdesk_name}} Support Team</p>',
    :requester_subject_template => "Ticket Updated - {{ticket.subject}}"
},
  { :notification_type => EmailNotification::REPLIED_BY_REQUESTER, 
      :account_id => account.id, :requester_notification => false, 
      :agent_notification => true,
      :agent_template => '<p>Hi {{ticket.agent.name}},<br /><br />The customer has responded to the ticket.<br /><br />{{ticket.subject}}<br /><br />Ticket comment<br />{{comment.body}}<br /><br />{{ticket.url}}</p>',
    :agent_subject_template => "New Reply Received - {{ticket.subject}}"
},
  { :notification_type => EmailNotification::TICKET_RESOLVED, 
      :account_id => account.id, :requester_notification => true, :agent_notification => false,
      :requester_template => '<p>Dear {{ticket.requester.name}},<br /><br />Our Support Rep has indicated that your ticket has been Resolved. <br /><br />If you believe that the ticket has not been resolved, please reply to this email to automatically reopen the ticket.<br />If there is no response from you, we will assume that the ticket has been resolved and the ticket will be automatically closed after 48 hours.<br /><br />Sincerely,<br />{{helpdesk_name}}Support Team<br />{{ticket.url}}</p>',
    :requester_subject_template => "Ticket Resolved - {{ticket.subject}}"
},
  {
    :notification_type => EmailNotification::ADDITIONAL_EMAIL_VERIFICATION,
    :account_id => account.id, :requester_notification => true, :agent_notification => false,
    :requester_template => '<p>Hi {{contact.name}},<br/><br/>This email address ({{email}}) has been added to your 
      {{helpdesk_name}} account. Please click on the link below to verify it.
      <br/><br/>Verification link: {{activation_url}}<br/><br/>If the link above does not work, 
      try copy-pasting the URL into your browser. Please get in touch with us if you need any help. 
      <br/><br/>Thanks, <br/>{{helpdesk_name}} <br/></p>',
    :requester_subject_template => '{{helpdesk_name}} Email Activation'
},
  { :notification_type => EmailNotification::TICKET_CLOSED, 
      :account_id => account.id, :requester_notification => true, :agent_notification => false,
      :requester_template => '<p>Dear {{ticket.requester.name}},<br /><br />Your ticket - {{ticket.subject}} -  has been closed.<br /><br />We hope that the ticket was resolved to your satisfaction. If you feel that the ticket should not be closed or if the ticket has not been resolved, please reply to this email.<br /><br />Sincerely,<br />{{helpdesk_name}} Support Team<br />{{ticket.url}}</p>',
    :requester_subject_template => "Ticket Closed - {{ticket.subject}}"
},
{ :notification_type => EmailNotification::DEFAULT_REPLY_TEMPLATE, 
      :account_id => account.id, :requester_notification => true, :agent_notification => false,
      :requester_template => '<p>Hi {{ticket.requester.name}},<br /><br />Ticket: {{ticket.url}}<br/></p>',
      :requester_subject_template => "{{ticket.subject}}"
},
{
    :notification_type => EmailNotification::ADDITIONAL_EMAIL_VERIFICATION,
    :account_id => account.id, :requester_notification => true, :agent_notification => false,
    :requester_template => '<p>Hi {{contact.name}},<br/><br/>This email address ({{email}}) has been added to your 
      {{helpdesk_name}} account. Please click on the link below to verify it.
      <br/><br/>Verification link: {{activation_url}}<br/><br/>If the link above does not work, 
      try copy-pasting the URL into your browser. Please get in touch with us if you need any help. 
      <br/><br/>Thanks, <br/>{{helpdesk_name}} <br/></p>',
    :requester_subject_template => '{{helpdesk_name}} Email Activation'
},
  {
  :notification_type => EmailNotification::NOTIFY_COMMENT,
  :account_id => account.id, :requester_notification => false, :agent_notification => true,
  :agent_template => '<p>Hi , <br/><br/> {{comment.commenter.name}} added a note and wants you to have a look.</p><br> Ticket URL:<br> {{ticket.url}} <br><br> Subject: <br>{{ticket.subject}}<br><br> Requester: {{ticket.requester.name}} <br><br> Note Content: <br> {{comment.body}}',
  :agent_subject_template => 'Note Added - [#{{ticket.id}}] {{ticket.subject}}'
},
{
  :notification_type => EmailNotification::NEW_TICKET_CC,
  :account_id => account.id, :requester_notification => true, :agent_notification => false,
  :requester_template => '<p>{{ticket.requester.name}} submitted a new ticket to {{ticket.portal_name}} and requested that we copy you</p><br><br>Ticket Description: <br>{{ticket.description}}',
  :requester_subject_template => 'Added as CC - [#{{ticket.id}}] {{ticket.subject}}'
},
{
  :notification_type => EmailNotification::PUBLIC_NOTE_CC,
  :account_id => account.id, :requester_notification => true, :agent_notification => false,
  :requester_template => '<p>There is a new comment in the ticket submitted by {{ticket.requester.name}} to {{ticket.portal_name}}</p><br> Comment added by : {{comment.commenter.name}}<br><br>Comment Content: <br>{{comment.body}}',
  :requester_subject_template => 'New comment - [#{{ticket.id}}] {{ticket.subject}}'
},
{
    :notification_type => EmailNotification::PREVIEW_EMAIL_VERIFICATION,
    :account_id => account.id, :requester_notification => false, :agent_notification => true,
    :agent_template => '<p>Hi agent,<br/><br/>This email is to give a preview of how customer satisfaction survey feedback is done.<br/><br/></p>',
    :agent_subject_template => '{{ticket.subject}}'
},
{
    :notification_type => EmailNotification::RESPONSE_SLA_REMINDER, 
    :account_id => account.id, 
    :requester_notification => false, 
    :agent_notification => true,
    :agent_template => '<p> Hi,<br><br>Response is due for ticket #{{ticket.id}}.<br><br>Ticket Details: <br><br>
                        Subject - {{ticket.subject}}<br><br>Requestor - {{ticket.requester.email}}<br><br>Ticket link - 
                        {{ticket.url}}<br><br>This is an reminder email from {{helpdesk_name}}</p>',
    :agent_subject_template => 'Response due for {{ticket.subject}}'
},
{
    :notification_type => EmailNotification::RESOLUTION_SLA_REMINDER, 
    :account_id => account.id, 
    :requester_notification => false, 
    :agent_notification => true,
    :agent_template => '<p>Hi,<br><br>Resolution time for ticket #{{ticket.id}} is fast approaching. 
                        The ticket is due by {{ticket.due_by_hrs}}.<br><br>Ticket Details: <br><br>Subject - {{ticket.subject}}<br>
                        <br>Requestor - {{ticket.requester.email}}<br><br>Ticket link - {{ticket.url}}<br><br>This is an escalation 
                        reminder email from {{helpdesk_name}}</p>',
    :agent_subject_template => 'Resolution expected - {{ticket.subject}}'
},
{
    :notification_type => EmailNotification::FIRST_RESPONSE_SLA_VIOLATION, 
    :account_id => account.id, 
    :requester_notification => false, 
    :agent_notification => true,
    :agent_template => '<p> Hi,<br><br>Response is due for ticket #{{ticket.id}}.<br><br>Ticket Details: <br><br>
                        Subject - {{ticket.subject}}<br><br>Requestor - {{ticket.requester.email}}<br><br>Ticket link - 
                        {{ticket.url}}<br><br>This is an reminder email from {{helpdesk_name}}</p>',
    :agent_subject_template => "Response due for {{ticket.subject}}"
},
{
    :notification_type => EmailNotification::RESOLUTION_TIME_SLA_VIOLATION, 
    :account_id => account.id, 
    :requester_notification => false, 
    :agent_notification => true,
    :agent_template => '<p>Hi,<br><br>Resolution time for ticket #{{ticket.id}} is fast approaching. 
                        The ticket is due by {{ticket.due_by_hrs}}.<br><br>Ticket Details: <br><br>Subject - {{ticket.subject}}<br>
                        <br>Requestor - {{ticket.requester.email}}<br><br>Ticket link - {{ticket.url}}<br><br>This is an escalation 
                        reminder email from {{helpdesk_name}}</p>',
    :agent_subject_template => "Resolution expected for  {{ticket.subject}}"
}
])
