class EmailNotification < ActiveRecord::Base
  belongs_to :account
  attr_protected  :account_id
  
  validates_uniqueness_of :notification_type, :scope => :account_id
  
  #Notification types
  NEW_TICKET = 1
  TICKET_ASSIGNED_TO_GROUP = 2
  TICKET_ASSIGNED_TO_AGENT = 3
  COMMENTED_BY_AGENT = 4
  #COMMENTED_BY_REQUESTER = 5
  REPLIED_BY_REQUESTER = 6
  TICKET_RESOLVED = 7
  TICKET_CLOSED = 8
  TICKET_REOPENED = 9
  
  EMAIL_SUBJECTS = {
    NEW_TICKET                => "Ticket Received - {{ticket.encoded_id}} {{ticket.subject}}",
    TICKET_ASSIGNED_TO_GROUP  => "Assigned to Group - {{ticket.encoded_id}} {{ticket.subject}}",
    TICKET_ASSIGNED_TO_AGENT  => "Ticket Assigned - {{ticket.encoded_id}} {{ticket.subject}}",
    COMMENTED_BY_AGENT        => "Ticket Updated - {{ticket.encoded_id}} {{ticket.subject}}",
    REPLIED_BY_REQUESTER      => "New Reply Received - {{ticket.encoded_id}} {{ticket.subject}}",
    TICKET_RESOLVED           => "Ticket Resolved - {{ticket.encoded_id}} {{ticket.subject}}",
    TICKET_CLOSED             => "Ticket Closed - {{ticket.encoded_id}} {{ticket.subject}}",
    TICKET_REOPENED           => "Ticket re-opened - {{ticket.encoded_id}} {{ticket.subject}}"
  }
end
