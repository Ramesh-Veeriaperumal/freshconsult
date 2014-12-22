class EmailNotification < ActiveRecord::Base
  has_many :dynamic_notification_templates
  belongs_to :account
  attr_protected  :account_id
  before_create :set_default_version
  # xss_sanitize  :only => [:requester_template, :agent_template, :requester_subject_template, :agent_subject_template], :html_sanitize => [:requester_template, :agent_template, :requester_subject_template, :agent_subject_template]

  def after_find
    if (self.version == 1)
      self.requester_template = (RedCloth.new(requester_template).to_html) if requester_template
      self.agent_template = (RedCloth.new(agent_template).to_html) if agent_template
    end
  end
  
  has_many :email_notification_agents, :class_name => "EmailNotificationAgent", :dependent => :destroy
  
  has_many :agents, :through => :email_notification_agents, :source => :user, 
              :conditions => { :users => {:deleted =>  false}}, :select => "users.id, users.email, users.name, users.language"
  
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
  # TICKET_REOPENED = 9
  
  #2nd batch
  USER_ACTIVATION = 10
  TICKET_UNATTENDED_IN_GROUP = 11
  FIRST_RESPONSE_SLA_VIOLATION = 12
  RESOLUTION_TIME_SLA_VIOLATION = 13
  PASSWORD_RESET = 14
  ADDITIONAL_EMAIL_VERIFICATION = 17

  DEFAULT_REPLY_TEMPLATE = 15
  
  EMAIL_SUBJECTS = {
    NEW_TICKET                    => "Ticket Received - {{ticket.encoded_id}} {{ticket.subject}}",
    TICKET_ASSIGNED_TO_GROUP      => "Assigned to Group - {{ticket.encoded_id}} {{ticket.subject}}",
    TICKET_ASSIGNED_TO_AGENT      => "Ticket Assigned - {{ticket.encoded_id}} {{ticket.subject}}",
    COMMENTED_BY_AGENT            => "Ticket Updated - {{ticket.encoded_id}} {{ticket.subject}}",
    REPLIED_BY_REQUESTER          => "New Reply Received - {{ticket.encoded_id}} {{ticket.subject}}",
    TICKET_RESOLVED               => "Ticket Resolved - {{ticket.encoded_id}} {{ticket.subject}}",
    TICKET_CLOSED                 => "Ticket Closed - {{ticket.encoded_id}} {{ticket.subject}}",
    # TICKET_REOPENED               => "Ticket re-opened - {{ticket.encoded_id}} {{ticket.subject}}",
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
                           # TICKET_REOPENED =>{:agent_notification => false},
                           REPLIED_BY_REQUESTER =>{:agent_notification =>false},
                           USER_ACTIVATION => {:requester_notification => false},
                           ADDITIONAL_EMAIL_VERIFICATION => {:requester_notification => false}
                         }
                          

  # Admin settings for email notifications
  VISIBILITY = {
    :AGENT_AND_REQUESTER   => 1,
    :AGENT_ONLY            => 2,
    :REQUESTER_ONLY        => 3,
    :REPLY_TEMPLATE        => 4
  }

  # notification_token, notification_type, visibility
  EMAIL_NOTIFICATIONS = [
    [:user_activation_email,  USER_ACTIVATION,                VISIBILITY[:AGENT_AND_REQUESTER]   ],
    [:password_reset_email,   PASSWORD_RESET,                 VISIBILITY[:AGENT_AND_REQUESTER]   ],
    [:new_ticket_created,     NEW_TICKET,                     VISIBILITY[:AGENT_AND_REQUESTER]   ],
    [:tkt_assigned_to_group,  TICKET_ASSIGNED_TO_GROUP,       VISIBILITY[:AGENT_ONLY]            ],
    [:tkt_unattended_in_grp,  TICKET_UNATTENDED_IN_GROUP,     VISIBILITY[:AGENT_ONLY]            ],
    [:tkt_assigned_to_agent,  TICKET_ASSIGNED_TO_AGENT,       VISIBILITY[:AGENT_ONLY]            ],
    [:agent_adds_comment,     COMMENTED_BY_AGENT,             VISIBILITY[:REQUESTER_ONLY]        ],
    [:first_response_sla,     FIRST_RESPONSE_SLA_VIOLATION,   VISIBILITY[:AGENT_ONLY]            ],
    [:requester_replies,      REPLIED_BY_REQUESTER,           VISIBILITY[:AGENT_ONLY]            ],
    [:resolution_time_sla,    RESOLUTION_TIME_SLA_VIOLATION,  VISIBILITY[:AGENT_ONLY]            ],
    [:agent_solves_tkt,       TICKET_RESOLVED,                VISIBILITY[:REQUESTER_ONLY]        ],
    [:agent_closes_tkt,       TICKET_CLOSED,                  VISIBILITY[:REQUESTER_ONLY]        ],
    [:default_reply_template, DEFAULT_REPLY_TEMPLATE,         VISIBILITY[:REPLY_TEMPLATE]        ],
    [:additional_email_verification, ADDITIONAL_EMAIL_VERIFICATION, VISIBILITY[:REQUESTER_ONLY]  ]
  ]
  
  # List of notfications to agents which cannot be turned off
  AGENT_MANDATORY_LIST = [ :user_activation_email, :password_reset_email ]
  # List of notfications to requester which cannot be turned off
  REQUESTER_MANDATORY_LIST = [ :password_reset_email ]

  TOKEN_BY_KEY  = Hash[*EMAIL_NOTIFICATIONS.map { |i| [i[1], i[0]] }.flatten]
  VISIBILITY_BY_KEY  = Hash[*EMAIL_NOTIFICATIONS.map { |i| [i[1], i[2]] }.flatten]

  def token
    TOKEN_BY_KEY[self.notification_type]
  end

  def visible_to_agent?
    [ VISIBILITY[:AGENT_AND_REQUESTER], VISIBILITY[:AGENT_ONLY] ].include? VISIBILITY_BY_KEY[self.notification_type]
  end

  def visible_to_requester?
    [ VISIBILITY[:AGENT_AND_REQUESTER], VISIBILITY[:REQUESTER_ONLY] ].include? VISIBILITY_BY_KEY[self.notification_type]
  end

  def reply_template?
    (VISIBILITY_BY_KEY[self.notification_type] == VISIBILITY[:REPLY_TEMPLATE])
  end

  def can_turn_off_for_agent?
    !AGENT_MANDATORY_LIST.include?(self.token)
  end

  def can_turn_off_for_requester?
    !REQUESTER_MANDATORY_LIST.include?(self.token)
  end

  def outdate_email_notification!(category)
    if (category == DynamicNotificationTemplate::CATEGORIES[:requester]) 
      templates = dynamic_notification_templates.requester_template.active
      self.outdated_requester_content = templates.any?{|x| x.outdated}  
    else
      templates = dynamic_notification_templates.agent_template.active
      self.outdated_agent_content = templates.any?{|x| x.outdated}
    end
    save
  end 

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

  def get_agent_plain_template(agent)
    template = get_agent_template(agent)
    Helpdesk::HTMLSanitizer.plain(template.last)
  end

  def get_requester_plain_template(requester)
    template = get_requester_template(requester)
    Helpdesk::HTMLSanitizer.plain(template.last)
  end

  def get_agent_template(agent)
    if (agent.nil? || agent.language.nil? || account.language == agent.language || !account.features?(:dynamic_content))
      template = [ agent_subject_template, agent_template]                  
    else  
      d_template = dynamic_notification_templates.agent_template.active.for_language(agent.language).first
      d_template ? [ d_template.subject, d_template.description ] : [ agent_subject_template, agent_template ]
    end
  end

  def return_template(type,language)
    if (type == DynamicNotificationTemplate::CATEGORIES[:requester])
      dynamic_notification_templates.requester_template.for_language(language)
    else
      dynamic_notification_templates.agent_template.for_language(language)
    end  
  end

  def get_requester_template(requester)
    if (requester.language.nil? || account.language == requester.language || !account.features?(:dynamic_content))
      template = [ requester_subject_template, requester_template ]
    else  
      d_template = dynamic_notification_templates.requester_template.active.for_language(requester.language).first
      d_template ? [ d_template.subject, d_template.description ] : [ requester_subject_template, requester_template ]
    end
  end

  def get_reply_template(user)
    if (user.language.nil? || user.account.language == user.language || !user.account.features?(:dynamic_content))
      template =requester_template
    else
       d_template = dynamic_notification_templates.requester_template.active.for_language(user.language).first
       d_template ? d_template.description : requester_template
    end     
  end  

  def self.disable_notification (account)
    Thread.current["notifications_#{account.id}"] = EmailNotification::DISABLE_NOTIFICATION  
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
    

    def set_default_version
      self.version = 2
    end
end
