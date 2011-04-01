account = Account.current

EmailNotification.seed_many(:account_id, :notification_type, [
  { :notification_type => EmailNotification::NEW_TICKET, 
      :account_id => account.id, :requester_notification => true, 
      :agent_notification => false,
      :requester_template => 'Dear {{ticket.requester.name}},

We would like to acknowledge that we have received your request and a ticket has been created with Ticket ID - {{ticket.id}}.
A support representative will be reviewing your request and will send you a personal response.(usually within 24 hours).

To view the status of the ticket or add comments, please visit 
{{ticket.url}}

Thank you for your patience.

Sincerely,
{{helpdesk_name}} Support Team' },
  { :notification_type => EmailNotification::TICKET_ASSIGNED_TO_GROUP, 
      :account_id => account.id, :requester_notification => false, 
      :agent_notification => true,
      :agent_template => 'Hi

A new ticket ({{ticket.id}}) has been assigned to your group "{{ticket.group.name}}". Please follow the link below to view the ticket.

{{ticket.subject}}
{{ticket.description}}
{{ticket.url}}' },
  { :notification_type => EmailNotification::TICKET_ASSIGNED_TO_AGENT, 
      :account_id => account.id, :requester_notification => false, 
      :agent_notification => true,
      :agent_template => 'Hi {{ticket.agent.name}},

A new ticket (Ticket ID - {{ticket.id}}) has been assigned to you. Please follow the link below to view the ticket.

{{ticket.subject}}
{{ticket.description}}
{{ticket.url}}' },
  { :notification_type => EmailNotification::COMMENTED_BY_AGENT, 
      :account_id => account.id, :requester_notification => true, 
      :agent_notification => false,
      :requester_template => 'Dear {{ticket.requester.name}},

There is a new comment on your Ticket (#{{ticket.id}}). You can view your ticket by visiting {{ticket.url}}
You can also reply to this email to add your comment.

Ticket comment 
{{comment.commenter.name}} - {{comment.body}}

Sincerely,
{{helpdesk_name}} Support Team' },
  { :notification_type => EmailNotification::REPLIED_BY_REQUESTER, 
      :account_id => account.id, :requester_notification => false, 
      :agent_notification => true,
      :agent_template => 'Hi {{ticket.agent.name}},

The customer has responded to the ticket (#{{ticket.id}})

{{ticket.subject}}

Ticket comment
{{comment.body}}

{{ticket.url}}' },
  { :notification_type => EmailNotification::TICKET_RESOLVED, 
      :account_id => account.id, :requester_notification => true, :agent_notification => false,
      :requester_template => 'Dear {{ticket.requester.name}},

Our Support Rep has indicated that your Ticket (#{{ticket.id}}) has been Resolved. 

If you believe that the ticket has not been resolved, please reply to this email to automatically reopen the ticket.
If there is no response from you, we will assume that the ticket has been resolved and the ticket will be automatically closed after 48 hours.

Sincerely,
{{helpdesk_name}} Support Team' },
  { :notification_type => EmailNotification::TICKET_CLOSED, 
      :account_id => account.id, :requester_notification => true, :agent_notification => false,
      :requester_template => 'Dear {{ticket.requester.name}},

Your Ticket #{{ticket.id}} - {{ticket.subject}} -  has been closed.

We hope that the ticket was resolved to your satisfaction. If you feel that the ticket should not be closed or if the ticket has not been resolved, please reply to this email.

Sincerely,
{{helpdesk_name}} Support Team' },
  { :notification_type => EmailNotification::TICKET_REOPENED, 
      :account_id => account.id, :requester_notification => false, :agent_notification => true,
      :agent_template => 'Hi {{ticket.agent.name}},

Ticket "#{{ticket.id}} - {{ticket.subject}}" has been reopened, please visit {{ticket.url}} to view the ticket.

Ticket comment
{{comment.body}}' }
])
