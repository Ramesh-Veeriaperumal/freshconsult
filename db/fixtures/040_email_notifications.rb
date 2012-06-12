account = Account.current

EmailNotification.seed_many(:account_id, :notification_type, [
  {
    :notification_type => EmailNotification::USER_ACTIVATION, 
    :account_id => account.id, 
    :requester_notification => true, 
    :agent_notification => true,
    :agent_template => '<p>Hi {{agent.name}},<br /><br />Your {{helpdesk_name}} account has been created.<br /><br />Click the url below to activate your account!<br /><br />{{activation_url}}<br /><br />If the above URL does not work try copying and pasting it into your browser. If you continue to have problems, please feel free to contact us.<br /><br />Regards,<br />{{helpdesk_name}}</p>',
    :requester_template => '<p>Hi {{contact.name}},<br /><br />A new {{helpdesk_name}} account has been created for you.<br /><br />Click the url below to activate your account and select a password!<br /><br />{{activation_url}}<br /><br />If the above URL does not work try copying and pasting it into your browser. If you continue to have problems, please feel free to contact us.<br /><br />Regards,<br />{{helpdesk_name}}</p>',
    :requester_subject_template => "{{ticket.portal_name}} user activation",
    :agent_subject_template => "{{ticket.portal_name}} user activation"
  },
  {
    :notification_type => EmailNotification::PASSWORD_RESET,
    :account_id => account.id, 
    :requester_notification => true, 
    :agent_notification => true,
    :agent_template => '<p>A request to reset your password has been made. If you did not make this request, simply ignore this email. If you did make this request, just click the link below:<br /><br />{{password_reset_url}}<br /><br />If the above URL does not work, try copying and pasting it into your browser. If you continue to have problem, please feel free to contact us.<br /><br />Regards,<br />{{helpdesk_name}}</p>',
    :requester_template => '<p>A request to reset your password has been made. If you did not make this request, simply ignore this email. If you did make this request, just click the link below:<br /><br />{{password_reset_url}}<br /><br />If the above URL does not work, try copying and pasting it into your browser. If you continue to have problem, please feel free to contact us.<br /><br />Regards,<br />{{helpdesk_name}}</p>',
    :requester_subject_template => "{{ticket.portal_name}} password reset instructions",
    :agent_subject_template => "{{ticket.portal_name}} password reset instructions"
  },
  { 
    :notification_type => EmailNotification::NEW_TICKET, 
    :account_id => account.id, :requester_notification => true, 
    :agent_notification => false,
    :agent_template => '<p>Hi,<br /><br />A new ticket has been created. <br />You may view and respond to the ticket here {{ticket.url}}<br /><br />Regards,<br />{{helpdesk_name}}</p>',
    :requester_template => '<p>Dear {{ticket.requester.name}},<br /><br />We would like to acknowledge that we have received your request and a ticket has been created with Ticket ID - {{ticket.id}}.<br />A support representative will be reviewing your request and will send you a personal response.(usually within 24 hours).<br /><br />To view the status of the ticket or add comments, please visit <br />{{ticket.url}}<br /><br />Thank you for your patience.<br /><br />Sincerely,<br />{{helpdesk_name}} Support Team</p>',
    :requester_subject_template => "Ticket Received - [\#{{ticket.id}}] {{ticket.subject}}",
    :agent_subject_template => "New Ticket has been created - [\#{{ticket.id}}] {{ticket.subject}}"
  },
  { :notification_type => EmailNotification::TICKET_ASSIGNED_TO_GROUP, 
      :account_id => account.id, :requester_notification => false, 
      :agent_notification => true,
      :agent_template => '<p>Hi<br /><br />A new ticket ({{ticket.id}}) has been assigned to your group "{{ticket.group.name}}". Please follow the link below to view the ticket.<br /><br />{{ticket.subject}}<br />{{ticket.description}}<br />{{ticket.url}}</p>',
    :agent_subject_template => "Assigned to Group - [\#{{ticket.id}}] {{ticket.subject}}"
},
  {
    :notification_type => EmailNotification::TICKET_UNATTENDED_IN_GROUP, 
    :account_id => account.id, 
    :requester_notification => false, 
    :agent_notification => true,
    :agent_template => '<p>Hi {{agent.name}},<br /><br />A new ticket (#{{ticket.id}}) in group {{ticket.group.name}} is currently unassigned for more than {{ticket.group.assign_time_mins}} minutes.<br /><br />Ticket Details: <br /><br />Subject - {{ticket.subject}}<br /><br />Description  - {{ticket.description}}<br /><br />This is an escalation email for the {{ticket.group.name}} group in {{helpdesk_name}}</p>',
    :agent_subject_template => "Unattended Ticket - [\#{{ticket.id}}] {{ticket.subject}}"
  },
  { :notification_type => EmailNotification::TICKET_ASSIGNED_TO_AGENT, 
      :account_id => account.id, :requester_notification => false, 
      :agent_notification => true,
      :agent_template => '<p>Hi {{ticket.agent.name}},<br /><br />A new ticket (Ticket ID - {{ticket.id}}) has been assigned to you. Please follow the link below to view the ticket.<br /><br />{{ticket.subject}}<br />{{ticket.description}}<br />{{ticket.url}}</p>',
    :agent_subject_template => "Ticket Assigned - [\#{{ticket.id}}] {{ticket.subject}}"
},
  { :notification_type => EmailNotification::COMMENTED_BY_AGENT, 
      :account_id => account.id, :requester_notification => true, 
      :agent_notification => false,
      :requester_template => '<p>Dear {{ticket.requester.name}},</p>
<p>There is a new comment on your Ticket (#{{ticket.id}}). You can view your ticket by visiting {{ticket.url}}<br />
You can also reply to this email to add your comment.</p>
<p>Ticket comment <br />
{{comment.commenter.name}} &#8211; {{comment.body}}</p>
<p>Sincerely,<br />
{{helpdesk_name}} Support Team</p>',
    :requester_subject_template => "Ticket Updated - [\#{{ticket.id}}] {{ticket.subject}}"
},
  { :notification_type => EmailNotification::REPLIED_BY_REQUESTER, 
      :account_id => account.id, :requester_notification => false, 
      :agent_notification => true,
      :agent_template => '<p>Hi {{ticket.agent.name}},<br /><br />The customer has responded to the ticket (#{{ticket.id}})<br /><br />{{ticket.subject}}<br /><br />Ticket comment<br />{{comment.body}}<br /><br />{{ticket.url}}</p>',
    :agent_subject_template => "New Reply Received - [\#{{ticket.id}}] {{ticket.subject}}"
},
  {
    :notification_type => EmailNotification::FIRST_RESPONSE_SLA_VIOLATION, 
    :account_id => account.id, 
    :requester_notification => false, 
    :agent_notification => true,
    :agent_template => '<p>Hi {{agent.name}},<br /><br />There has been no response from the helpdesk for Ticket ID #{{ticket.id}}. The first response was due by {{ticket.fr_due_by_hrs}} today.<br /><br />Ticket Details: <br /><br />Subject - {{ticket.subject}}<br /><br />Requestor - {{ticket.requester.email}}<br /><br />This is an escalation email from {{helpdesk_name}}</p>',
    :agent_subject_template => "Response time SLA violated - [\#{{ticket.id}}] {{ticket.subject}}"
  },
  {
    :notification_type => EmailNotification::RESOLUTION_TIME_SLA_VIOLATION, 
    :account_id => account.id, 
    :requester_notification => false, 
    :agent_notification => true,
    :agent_template => '<p>Hi {{agent.name}},<br /><br />Ticket #{{ticket.id}} has not been resolved within the SLA time period. The ticket was due by {{ticket.due_by_hrs}} today.<br /><br />Ticket Details: <br /><br />Subject - {{ticket.subject}}<br /><br />Requestor - {{ticket.requester.email}}<br /><br />This is an escalation email from {{helpdesk_name}}</p>',
    :agent_subject_template => "Resolution time SLA violated - [\#{{ticket.id}}] {{ticket.subject}}"
  },
  { :notification_type => EmailNotification::TICKET_RESOLVED, 
      :account_id => account.id, :requester_notification => true, :agent_notification => false,
      :requester_template => '<p>Dear {{ticket.requester.name}},<br /><br />Our Support Rep has indicated that your Ticket (#{{ticket.id}}) has been Resolved. <br /><br />If you believe that the ticket has not been resolved, please reply to this email to automatically reopen the ticket.<br />If there is no response from you, we will assume that the ticket has been resolved and the ticket will be automatically closed after 48 hours.<br /><br />Sincerely,<br />{{helpdesk_name}} Support Team</p>',
    :requester_subject_template => "Ticket Resolved - [\#{{ticket.id}}] {{ticket.subject}}"
},
  { :notification_type => EmailNotification::TICKET_CLOSED, 
      :account_id => account.id, :requester_notification => true, :agent_notification => false,
      :requester_template => '<p>Dear {{ticket.requester.name}},<br /><br />Your Ticket #{{ticket.id}} - {{ticket.subject}} -  has been closed.<br /><br />We hope that the ticket was resolved to your satisfaction. If you feel that the ticket should not be closed or if the ticket has not been resolved, please reply to this email.<br /><br />Sincerely,<br />{{helpdesk_name}} Support Team</p>',
    :requester_subject_template => "Ticket Closed - [\#{{ticket.id}}] {{ticket.subject}}"
},
  { :notification_type => EmailNotification::TICKET_REOPENED, 
      :account_id => account.id, :requester_notification => false, :agent_notification => true,
      :agent_template => '<p>Hi {{ticket.agent.name}},<br /><br />Ticket "#{{ticket.id}} - {{ticket.subject}}" has been reopened, please visit {{ticket.url}} to view the ticket.<br /><br />Ticket comment<br />{{comment.body}}</p>',
    :agent_subject_template => "Ticket re-opened - [\#{{ticket.id}}] {{ticket.subject}}"
}
])
