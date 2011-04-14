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
  
  #2nd batch
  USER_ACTIVATION = 10
  TICKET_UNATTENDED_IN_GROUP = 11
  FIRST_RESPONSE_SLA_VIOLATION = 12
  RESOLUTION_TIME_SLA_VIOLATION = 13
  PASSWORD_RESET = 14
  
  EMAIL_SUBJECTS = {
    NEW_TICKET                    => "Ticket Received - {{ticket.encoded_id}} {{ticket.subject}}",
    TICKET_ASSIGNED_TO_GROUP      => "Assigned to Group - {{ticket.encoded_id}} {{ticket.subject}}",
    TICKET_ASSIGNED_TO_AGENT      => "Ticket Assigned - {{ticket.encoded_id}} {{ticket.subject}}",
    COMMENTED_BY_AGENT            => "Ticket Updated - {{ticket.encoded_id}} {{ticket.subject}}",
    REPLIED_BY_REQUESTER          => "New Reply Received - {{ticket.encoded_id}} {{ticket.subject}}",
    TICKET_RESOLVED               => "Ticket Resolved - {{ticket.encoded_id}} {{ticket.subject}}",
    TICKET_CLOSED                 => "Ticket Closed - {{ticket.encoded_id}} {{ticket.subject}}",
    TICKET_REOPENED               => "Ticket re-opened - {{ticket.encoded_id}} {{ticket.subject}}",
    TICKET_UNATTENDED_IN_GROUP    => "Unattended Ticket - {{ticket.encoded_id}} {{ticket.subject}}",
    FIRST_RESPONSE_SLA_VIOLATION  => "Response time SLA violated - {{ticket.encoded_id}} {{ticket.subject}}",
    RESOLUTION_TIME_SLA_VIOLATION => "Resolution time SLA violated - {{ticket.encoded_id}} {{ticket.subject}}"
  }
  
  def ticket_subject(ticket)
    Liquid::Template.parse(EMAIL_SUBJECTS[notification_type]).render('ticket' => ticket)
  end
end
