account = Account.current

EmailNotification.seed_many(:account_id, :notification_type, [
  { :notification_type => EmailNotification::DEFAULT_REPLY_TEMPLATE, 
        :account_id => account.id, :requester_notification => false, :agent_notification => false,
        :requester_template => '<p>Hi {{ticket.requester.name}},<br /><br />Ticket: {{ticket.url}}<br/></p>',
        :requester_subject_template => "{{ticket.subject}}"
  },
  { 
    :notification_type => EmailNotification::DEFAULT_FORWARD_TEMPLATE, 
    :account_id => account.id, 
    :requester_notification => false, 
    :agent_notification => false,
    :requester_template => '<p>Please take a look at ticket <a href="{{ticket.url}}">#{{ticket.id}}</a> raised by {{ticket.requester.name}} ({{ticket.requester.email}}).</p>',
    :requester_subject_template => "{{ticket.subject}}"
  }

])