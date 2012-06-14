account = Account.current

EmailNotification.seed_many(:account_id, :notification_type, [
  {
    :notification_type => EmailNotification::USER_ACTIVATION, 
    :account_id => account.id, 
    :requester_notification => true, 
    :agent_notification => true,
    :agent_template => '<p>Hi <span style="color: #1f497d;">{{agent.name}}</span>,<br /><br />Your <span style="color: #1f497d;">{{helpdesk_name}}</span> account has been created.<br /><br />Click the url below to activate your account!<br /><br /><span style="color: #1f497d;">{{activation_url}}</span><br /><br />If the above URL does not work try copying and pasting it into your browser. If you continue to have problems, please feel free to contact us.<br /><br />Regards,<br /><span style="color: #1f497d;">{{helpdesk_name}}</span></p>',
    :requester_template => '<p>Hi <span style="color: #1f497d;">{{contact.name}}</span>,<br /><br />A new <span style="color: #1f497d;">{{helpdesk_name}}</span> account has been created for you.<br /><br />Click the url below to activate your account and select a password!<br /><br /><span style="color: #1f497d;">{{activation_url}}</span><br /><br />If the above URL does not work try copying and pasting it into your browser. If you continue to have problems, please feel free to contact us.<br/><br/>Regards,<br/><span style="color: #1f497d;">{{helpdesk_name}}</span></p>',
    :requester_subject_template => "{{ticket.portal_name}} user activation",
    :agent_subject_template => "{{ticket.portal_name}} user activation"
  },
  {
    :notification_type => EmailNotification::PASSWORD_RESET,
    :account_id => account.id, 
    :requester_notification => true, 
    :agent_notification => true,
    :agent_template => '<p>A request to reset your password has been made. If you did not make this request, simply ignore this email. If you did make this request, just click the link below:<br /><br /><span style="color: #1f497d;">{{password_reset_url}}</span><br /><br />If the above URL does not work, try copying and pasting it into your browser. If you continue to have problem, please feel free to contact us.<br /><br />Regards,<br /><span style="color: #1f497d;">{{helpdesk_name}}</span></p>',
    :requester_template => '<p>A request to reset your password has been made. If you did not make this request, simply ignore this email. If you did make this request, just click the link below:<br /><br /><span style="color: #1f497d;">{{password_reset_url}}</span><br /><br />If the above URL does not work, try copying and pasting it into your browser. If you continue to have problem, please feel free to contact us.<br /><br />Regards,<br /><span style="color: #1f497d;">{{helpdesk_name}}</span></p>',
    :requester_subject_template => "{{ticket.portal_name}} password reset instructions",
    :agent_subject_template => "{{ticket.portal_name}} password reset instructions"
  },
  { 
    :notification_type => EmailNotification::NEW_TICKET, 
    :account_id => account.id, :requester_notification => true, 
    :agent_notification => false,
    :agent_template => '<p>Hi,<br /><br />A new ticket has been created. <br />You may view and respond to the ticket here <span style="color: #1f497d;">{{ticket.url}}</span><br /><br />Regards,<br /><span style="color: #1f497d;">{{helpdesk_name}}</span></p>',
    :requester_template => '<p>Dear <span style="color: #1f497d;">{{ticket.requester.name}}</span>,<br /><br />We would like to acknowledge that we have received your request and a ticket has been created with Ticket ID - <span style="color: #1f497d;">{{ticket.id}}</span>.<br />A support representative will be reviewing your request and will send you a personal response.(usually within 24 hours).<br /><br />To view the status of the ticket or add comments, please visit <br /><span style="color: #1f497d;">{{ticket.url}}</span><br /><br />Thank you for your patience.<br /><br />Sincerely,<br /><span style="color: #1f497d;">{{helpdesk_name}}</span> Support Team</p>',
    :requester_subject_template => "Ticket Received - [\#{{ticket.id}}] {{ticket.subject}}",
    :agent_subject_template => "New Ticket has been created - [\#{{ticket.id}}] {{ticket.subject}}"
  },
  { :notification_type => EmailNotification::TICKET_ASSIGNED_TO_GROUP, 
      :account_id => account.id, :requester_notification => false, 
      :agent_notification => true,
      :agent_template => '<p>Hi<br /><br />A new ticket (<span style="color: #1f497d;">{{ticket.id}}</span>) has been assigned to your group <span style="color: #1f497d;">"{{ticket.group.name}}"</span>. Please follow the link below to view the ticket.<br /><br /><span style="color: #1f497d;">{{ticket.subject}}</span><br /><span style="color: #1f497d;">{{ticket.description}}</span><br /><span style="color: #1f497d;">{{ticket.url}}</span></p>',
    :agent_subject_template => "Assigned to Group - [\#{{ticket.id}}] {{ticket.subject}}"
},
  {
    :notification_type => EmailNotification::TICKET_UNATTENDED_IN_GROUP, 
    :account_id => account.id, 
    :requester_notification => false, 
    :agent_notification => true,
    :agent_template => '<p>Hi <span style="color: #1f497d;">{{agent.name}}</span>,<br /><br />A new ticket (#<span style="color: #1f497d;">{{ticket.id}}</span>) in group <span style="color: #1f497d;">{{ticket.group.name}}</span> is currently unassigned for more than <span style="color: #1f497d;">{{ticket.group.assign_time_mins}}</span> minutes.<br /><br />Ticket Details: <br /><br />Subject - <span style="color: #1f497d;">{{ticket.subject}}</span><br /><br />Description  - <span style="color: #1f497d;">{{ticket.description}}</span><br /><br />This is an escalation email for the <span style="color: #1f497d;">{{ticket.group.name}}</span> group in <span style="color: #1f497d;">{{helpdesk_name}}</span></p>',
    :agent_subject_template => "Unattended Ticket - [\#{{ticket.id}}] {{ticket.subject}}"
  },
  { :notification_type => EmailNotification::TICKET_ASSIGNED_TO_AGENT, 
      :account_id => account.id, :requester_notification => false, 
      :agent_notification => true,
      :agent_template => '<p>Hi <span style="color: #1f497d;">{{ticket.agent.name}}</span>,<br /><br />A new ticket (Ticket ID - <span style="color: #1f497d;">{{ticket.id}}</span>) has been assigned to you. Please follow the link below to view the ticket.<br /><br /><span style="color: #1f497d;">{{ticket.subject}}</span><br /><span style="color: #1f497d;">{{ticket.description}}</span><br /><span style="color: #1f497d;">{{ticket.url}}</span></p>',
    :agent_subject_template => "Ticket Assigned - [\#{{ticket.id}}] {{ticket.subject}}"
},
  { :notification_type => EmailNotification::COMMENTED_BY_AGENT, 
      :account_id => account.id, :requester_notification => true, 
      :agent_notification => false,
      :requester_template => '<p>Dear <span style="color: #1f497d;">{{ticket.requester.name}}</span>,<br/>There is a new comment on your Ticket (#{{ticket.id}}). You can view your ticket by visiting {{ticket.url}}<br />You can also reply to this email to add your comment.<br/>Ticket comment <br /><span style="color: #1f497d;">{{comment.commenter.name}}</span> &#8211; {{comment.body}}<br/>Sincerely,<br /><span style="color: #1f497d;">{{helpdesk_name}}</span> Support Team</p>',
    :requester_subject_template => "Ticket Updated - [\#{{ticket.id}}] {{ticket.subject}}"
},
  { :notification_type => EmailNotification::REPLIED_BY_REQUESTER, 
      :account_id => account.id, :requester_notification => false, 
      :agent_notification => true,
      :agent_template => '<p>Hi <span style="color: #1f497d;">{{ticket.agent.name}}</span>,<br /><br />The customer has responded to the ticket (#<span style="color: #1f497d;">{{ticket.id}}</span>)<br /><br /><span style="color: #1f497d;">{{ticket.subject}}</span><br /><br />Ticket comment<br /><span style="color: #1f497d;">{{comment.body}}</span><br /><br /><span style="color: #1f497d;">{{ticket.url}}</span></p>',
    :agent_subject_template => "New Reply Received - [\#{{ticket.id}}] {{ticket.subject}}"
},
  {
    :notification_type => EmailNotification::FIRST_RESPONSE_SLA_VIOLATION, 
    :account_id => account.id, 
    :requester_notification => false, 
    :agent_notification => true,
    :agent_template => '<p>Hi <span style="color: #1f497d;">{{agent.name}}</span>,<br /><br />There has been no response from the helpdesk for Ticket ID #<span style="color: #1f497d;">{{ticket.id}}</span>. The first response was due by <span style="color: #1f497d;">{{ticket.fr_due_by_hrs}}</span> today.<br /><br />Ticket Details: <br /><br />Subject - <span style="color: #1f497d;">{{ticket.subject}}</span><br /><br />Requestor - <span style="color: #1f497d;">{{ticket.requester.email}}</span><br /><br />This is an escalation email from <span style="color: #1f497d;">{{helpdesk_name}}</span></p>',
    :agent_subject_template => "Response time SLA violated - [\#{{ticket.id}}] {{ticket.subject}}"
  },
  {
    :notification_type => EmailNotification::RESOLUTION_TIME_SLA_VIOLATION, 
    :account_id => account.id, 
    :requester_notification => false, 
    :agent_notification => true,
    :agent_template => '<p>Hi <span style="color: #1f497d;">{{agent.name}}</span>,<br /><br />Ticket #<span style="color: #1f497d;">{{ticket.id}}</span> has not been resolved within the SLA time period. The ticket was due by <span style="color: #1f497d;">{{ticket.due_by_hrs}}</span> today.<br /><br />Ticket Details: <br /><br />Subject - <span style="color: #1f497d;">{{ticket.subject}}</span><br /><br />Requestor - <span style="color: #1f497d;">{{ticket.requester.email}}</span><br /><br />This is an escalation email from <span style="color: #1f497d;">{{helpdesk_name}}</span></p>',
    :agent_subject_template => "Resolution time SLA violated - [\#{{ticket.id}}] {{ticket.subject}}"
  },
  { :notification_type => EmailNotification::TICKET_RESOLVED, 
      :account_id => account.id, :requester_notification => true, :agent_notification => false,
      :requester_template => '<p>Dear <span style="color: #1f497d;">{{ticket.requester.name}}</span>,<br /><br />Our Support Rep has indicated that your Ticket (#<span style="color: #1f497d;">{{ticket.id}}</span>) has been Resolved. <br /><br />If you believe that the ticket has not been resolved, please reply to this email to automatically reopen the ticket.<br />If there is no response from you, we will assume that the ticket has been resolved and the ticket will be automatically closed after 48 hours.<br /><br />Sincerely,<br /><span style="color: #1f497d;">{{helpdesk_name}}</span> Support Team</p>',
    :requester_subject_template => "Ticket Resolved - [\#{{ticket.id}}] {{ticket.subject}}"
},
  { :notification_type => EmailNotification::TICKET_CLOSED, 
      :account_id => account.id, :requester_notification => true, :agent_notification => false,
      :requester_template => '<p>Dear <span style="color: #1f497d;">{{ticket.requester.name}}</span>,<br /><br />Your Ticket #<span style="color: #1f497d;">{{ticket.id}}</span> - <span style="color: #1f497d;">{{ticket.subject}}</span> -  has been closed.<br /><br />We hope that the ticket was resolved to your satisfaction. If you feel that the ticket should not be closed or if the ticket has not been resolved, please reply to this email.<br /><br />Sincerely,<br /><span style="color: #1f497d;">{{helpdesk_name}}</span> Support Team</p>',
    :requester_subject_template => "Ticket Closed - [\#{{ticket.id}}] {{ticket.subject}}"
},
  { :notification_type => EmailNotification::TICKET_REOPENED, 
      :account_id => account.id, :requester_notification => false, :agent_notification => true,
      :agent_template => '<p>Hi <span style="color: #1f497d;">{{ticket.agent.name}}</span>,<br /><br />Ticket <span style="color: #1f497d;">"#{{ticket.id}} - {{ticket.subject}}"</span> has been reopened, please visit <span style="color: #1f497d;">{{ticket.url}}</span> to view the ticket.<br /><br />Ticket comment<br /><span style="color: #1f497d;">{{comment.body}}</span></p>',
    :agent_subject_template => "Ticket re-opened - [\#{{ticket.id}}] {{ticket.subject}}"
}
])
