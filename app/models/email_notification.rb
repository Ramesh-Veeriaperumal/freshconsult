class EmailNotification < ActiveRecord::Base
  belongs_to :account
  attr_protected  :account_id

def before_create
  self.version = 2
end

  def after_find
    if (self.version == 1)
      self.requester_template = (RedCloth.new(requester_template).to_html) if requester_template
      self.agent_template = (RedCloth.new(agent_template).to_html) if agent_template
    end
  end
  
  has_many :email_notification_agents, :class_name => "EmailNotificationAgent", :dependent => :destroy
  
  has_many :agents, :through => :email_notification_agents, :source => :user, 
              :conditions => { :users => {:deleted =>  false}}, :select => "users.id, users.email"
  
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
  
  
  DISABLE_NOTIFICATION = { NEW_TICKET =>{ :requester_notification => false, :agent_notification => false },
                           TICKET_ASSIGNED_TO_GROUP =>{:agent_notification =>false},
                           TICKET_ASSIGNED_TO_AGENT => {:agent_notification => false},
                           TICKET_RESOLVED => {:requester_notification => false},
                           TICKET_CLOSED => {:requester_notification => false},
                           COMMENTED_BY_AGENT =>{:requester_notification => false},
                           TICKET_RESOLVED =>{:requester_notification => false},
                           TICKET_REOPENED =>{:agent_notification => false},
                           REPLIED_BY_REQUESTER =>{:agent_notification =>false},
                           USER_ACTIVATION => {:requester_notification => false}
                           
                         }
                          

  
  def ticket_subject(ticket)
    Liquid::Template.parse(EMAIL_SUBJECTS[notification_type]).render('ticket' => ticket)
  end
  
  def agent_notification?
    agent_notification && allowed_in_thread_local?(:agent_notification)
  end
  
  def requester_notification?
    requester_notification && allowed_in_thread_local?(:requester_notification)
  end
  
  def formatted_agent_template
    agent_template
  end
  
  def formatted_requester_template
    requester_template
  end
  
  def self.disable_notification (account)
     Thread.current["notifications_#{account.id}"] = EmailNotification::DISABLE_NOTIFICATION   
  end

  def self.enable_notification (account)
    Thread.current["notifications_#{account.id}"] = nil
  end

  private
    #Introduced to restrict notification storm, during other helpdesks data import.
    #Notification can be disabled for requesters and ticket creation in the import thread.
    #Format to use is 
    #Thread.current[:notifications][<notification type>][:agent|:requester_notification]
    #For ex., Thread.current[:notifications][1][:requester_notification] = false
    def allowed_in_thread_local?(user_role)
      (n_hash = Thread.current["notifications_#{account_id}"]).nil? || 
        (my_hash = n_hash[notification_type]).nil? || !my_hash[user_role].eql?(false)
    end
    
end
