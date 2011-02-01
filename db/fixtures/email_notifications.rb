account = Account.first
EmailNotification.seed_many(:notification_type, [
  { :notification_type => EmailNotification::NEW_TICKET, :account => account, :requester_notification => true, :agent_notification => false },
  { :notification_type => EmailNotification::TICKET_ASSIGNED_TO_GROUP, :account => account, :requester_notification => false, :agent_notification => true },
  { :notification_type => EmailNotification::TICKET_ASSIGNED_TO_AGENT, :account => account, :requester_notification => false, :agent_notification => true },
  { :notification_type => EmailNotification::COMMENTED_BY_AGENT, :account => account, :requester_notification => true, :agent_notification => false },
  { :notification_type => EmailNotification::COMMENTED_BY_REQUESTER, :account => account, :requester_notification => false, :agent_notification => true },
  { :notification_type => EmailNotification::REPLIED_BY_REQUESTER, :account => account, :requester_notification => false, :agent_notification => true },
  { :notification_type => EmailNotification::TICKET_RESOLVED, :account => account, :requester_notification => true, :agent_notification => false },
  { :notification_type => EmailNotification::TICKET_CLOSED, :account => account, :requester_notification => true, :agent_notification => false },
  { :notification_type => EmailNotification::TICKET_REOPENED, :account => account, :requester_notification => false, :agent_notification => true }
])
