class EmailNotification < ActiveRecord::Base
  self.primary_key = :id
  has_many :dynamic_notification_templates
  belongs_to_account
  attr_protected  :account_id
  before_create :set_default_version

  include EmailNotificationConstants

  xss_sanitize  :only => [:requester_template, :agent_template, :requester_subject_template, :agent_subject_template], :decode_calm_sanitizer => [:requester_template, :agent_template, :requester_subject_template, :agent_subject_template]

  def set_requester_and_agent_template
    if (self.version == 1)
      self.requester_template = (RedCloth.new(requester_template).to_html) if requester_template
      self.agent_template = (RedCloth.new(agent_template).to_html) if agent_template
    end
    self
  end

  has_many :email_notification_agents, :class_name => "EmailNotificationAgent", :dependent => :destroy

  has_many :agents, :through => :email_notification_agents, :source => :user, 
              :conditions => { :users => {:deleted =>  false}}, :select => "users.id, users.email, users.name, users.language"

  validates_uniqueness_of :notification_type, :scope => :account_id

  SOURCE_IS_AUTOMAION_RULE = 15
  #Notification types
  NEW_TICKET                = 1
  TICKET_ASSIGNED_TO_GROUP  = 2
  TICKET_ASSIGNED_TO_AGENT  = 3
  COMMENTED_BY_AGENT        = 4
  #COMMENTED_BY_REQUESTER   = 5
  REPLIED_BY_REQUESTER      = 6
  TICKET_RESOLVED           = 7
  TICKET_CLOSED             = 8
  # TICKET_REOPENED = 9

  #2nd batch
  USER_ACTIVATION               = 10
  AGENT_INVITATION              = 25
  TICKET_UNATTENDED_IN_GROUP    = 11
  FIRST_RESPONSE_SLA_VIOLATION  = 12
  RESOLUTION_TIME_SLA_VIOLATION = 13
  PASSWORD_RESET                = 14
  ADDITIONAL_EMAIL_VERIFICATION = 17
  NEW_TICKET_CC                 = 19
  PUBLIC_NOTE_CC                = 20
  NOTIFY_COMMENT                = 21
  AUTOMATED_PRIVATE_NOTES       = 26

  DEFAULT_REPLY_TEMPLATE  = 15
  RESPONSE_SLA_REMINDER   = 22
  RESOLUTION_SLA_REMINDER = 23
  DEFAULT_FORWARD_TEMPLATE = 24

  NEXT_RESPONSE_SLA_REMINDER  = 27
  NEXT_RESPONSE_SLA_VIOLATION = 28

  # Bot template
  BOT_RESPONSE_TEMPLATE = 201

  DISABLE_NOTIFICATION = {
    NEW_TICKET =>  { 
      :requester_notification => false, 
      :agent_notification     => false 
    },
    TICKET_ASSIGNED_TO_GROUP      =>  {:agent_notification => false},
    TICKET_ASSIGNED_TO_AGENT      =>  {:agent_notification => false},
    TICKET_RESOLVED               =>  {:requester_notification => false},
    TICKET_CLOSED                 =>  {:requester_notification => false},
    COMMENTED_BY_AGENT            =>  {:requester_notification => false},
    TICKET_RESOLVED               =>  {:requester_notification => false},
    #TICKET_REOPENED              =>  {:agent_notification => false},
    REPLIED_BY_REQUESTER          =>  {:agent_notification => false},
    USER_ACTIVATION               =>  {:requester_notification => false},
    ADDITIONAL_EMAIL_VERIFICATION =>  {:requester_notification => false},
    AGENT_INVITATION              =>  {:requester_notification => false}
  }


  # Admin settings for email notifications
  VISIBILITY = {
    :AGENT_AND_REQUESTER   => 1,
    :AGENT_ONLY            => 2,
    :REQUESTER_ONLY        => 3,
    :REPLY_TEMPLATE        => 4,
    :CC_NOTIFICATION       => 5,
    :FORWARD_TEMPLATE      => 6
  }

  # notification_token, notification_type, visibility
  EMAIL_NOTIFICATIONS = [
    [:user_activation_email,          USER_ACTIVATION,                VISIBILITY[:AGENT_AND_REQUESTER]],
    [:agent_invitation_email,         AGENT_INVITATION,               VISIBILITY[:AGENT_ONLY]],
    [:password_reset_email,           PASSWORD_RESET,                 VISIBILITY[:AGENT_AND_REQUESTER]],
    [:new_ticket_created,             NEW_TICKET,                     VISIBILITY[:AGENT_AND_REQUESTER]],
    [:tkt_assigned_to_group,          TICKET_ASSIGNED_TO_GROUP,       VISIBILITY[:AGENT_ONLY]         ],
    [:tkt_unattended_in_grp,          TICKET_UNATTENDED_IN_GROUP,     VISIBILITY[:AGENT_ONLY]         ],
    [:tkt_assigned_to_agent,          TICKET_ASSIGNED_TO_AGENT,       VISIBILITY[:AGENT_ONLY]         ],
    [:agent_adds_comment,             COMMENTED_BY_AGENT,             VISIBILITY[:REQUESTER_ONLY]     ],
    [:first_response_sla,             FIRST_RESPONSE_SLA_VIOLATION,   VISIBILITY[:AGENT_ONLY]         ],
    [:response_reminder_sla,          RESPONSE_SLA_REMINDER,          VISIBILITY[:AGENT_ONLY]         ],
    [:requester_replies,              REPLIED_BY_REQUESTER,           VISIBILITY[:AGENT_ONLY]         ],
    [:resolution_time_sla,            RESOLUTION_TIME_SLA_VIOLATION,  VISIBILITY[:AGENT_ONLY]         ],
    [:resolution_reminder_sla,        RESOLUTION_SLA_REMINDER,        VISIBILITY[:AGENT_ONLY]         ],
    [:agent_solves_tkt,               TICKET_RESOLVED,                VISIBILITY[:REQUESTER_ONLY]     ],
    [:agent_closes_tkt,               TICKET_CLOSED,                  VISIBILITY[:REQUESTER_ONLY]     ],
    [:default_reply_template,         DEFAULT_REPLY_TEMPLATE,         VISIBILITY[:REPLY_TEMPLATE]     ],
    [:default_forward_template,       DEFAULT_FORWARD_TEMPLATE,       VISIBILITY[:FORWARD_TEMPLATE]   ],
    [:additional_email_verification,  ADDITIONAL_EMAIL_VERIFICATION,  VISIBILITY[:REQUESTER_ONLY]     ],
    [:notify_comment,                 NOTIFY_COMMENT,                 VISIBILITY[:AGENT_ONLY]         ],
    [:automated_private_notes,        AUTOMATED_PRIVATE_NOTES,        VISIBILITY[:AGENT_ONLY]         ],
    [:new_ticket_cc,                  NEW_TICKET_CC,                  VISIBILITY[:CC_NOTIFICATION]    ],
    [:public_note_cc,                 PUBLIC_NOTE_CC,                 VISIBILITY[:CC_NOTIFICATION]    ],
    [:bot_response_template,          BOT_RESPONSE_TEMPLATE,          VISIBILITY[:REQUESTER_ONLY]     ],
    [:next_response_reminder_sla,     NEXT_RESPONSE_SLA_REMINDER,     VISIBILITY[:AGENT_ONLY]         ],
    [:next_response_sla,              NEXT_RESPONSE_SLA_VIOLATION,    VISIBILITY[:AGENT_ONLY]         ]
  ]

  # List of notfications to agents which cannot be turned off
  AGENT_MANDATORY_LIST = [:user_activation_email, :password_reset_email, :notify_comment, :agent_invitation_email, :automated_private_notes].freeze
  # List of notfications to requester which cannot be turned off
  REQUESTER_MANDATORY_LIST = [ :password_reset_email ]
  # List of notifications not visible under admin's
  CUSTOM_NOTIFICATION_LIST = [ BOT_RESPONSE_TEMPLATE ]

  TOKEN_BY_KEY  = Hash[*EMAIL_NOTIFICATIONS.map { |i| [i[1], i[0]] }.flatten]
  VISIBILITY_BY_KEY  = Hash[*EMAIL_NOTIFICATIONS.map { |i| [i[1], i[2]] }.flatten]
  
  AGENT_MANDATORY_KEYS = AGENT_MANDATORY_LIST.map{ |i| TOKEN_BY_KEY.key(i)}
  REQUESTER_MANDATORY_KEYS = REQUESTER_MANDATORY_LIST.map{ |i| TOKEN_BY_KEY.key(i)}

  BCC_DISABLED_NOTIFICATIONS = [NOTIFY_COMMENT, PUBLIC_NOTE_CC, NEW_TICKET_CC, AUTOMATED_PRIVATE_NOTES].freeze

  CUSTOM_CATEGORY_ID_ENABLED_NOTIFICATIONS = [NEW_TICKET, NEW_TICKET_CC, USER_ACTIVATION, EMAIL_TO_REQUESTOR]

  scope :response_sla_reminder, :conditions => { :notification_type => RESPONSE_SLA_REMINDER } 
  scope :resolution_sla_reminder, :conditions => { :notification_type => RESOLUTION_SLA_REMINDER }
  scope :next_response_sla_reminder, :conditions => { :notification_type => NEXT_RESPONSE_SLA_REMINDER }
  scope :non_sla_notifications, :conditions => ["notification_type not in (?)", [TICKET_UNATTENDED_IN_GROUP,FIRST_RESPONSE_SLA_VIOLATION,RESOLUTION_TIME_SLA_VIOLATION,RESPONSE_SLA_REMINDER,RESOLUTION_SLA_REMINDER,NEXT_RESPONSE_SLA_REMINDER,NEXT_RESPONSE_SLA_VIOLATION]]

  def token
    TOKEN_BY_KEY[self.notification_type]
  end

  def visible_only_to_agent?
    [ VISIBILITY[:AGENT_ONLY] ].include? VISIBILITY_BY_KEY[self.notification_type]
  end

  def visible_to_agent?
    return false if token == :password_reset_email and account.freshid_integration_enabled?
    return false if token == :agent_invitation_email and !account.freshid_integration_enabled?
    EmailNotification.agent_visible_template?(self.notification_type)
  end

  def visible_to_requester?
    return false if CUSTOM_NOTIFICATION_LIST.include? (self.notification_type)
    EmailNotification.requester_visible_template?(self.notification_type)
  end

  def reply_template?
    (VISIBILITY_BY_KEY[self.notification_type] == VISIBILITY[:REPLY_TEMPLATE])
  end

  def forward_template?
    (VISIBILITY_BY_KEY[self.notification_type] == VISIBILITY[:FORWARD_TEMPLATE])
  end

  def cc_notification?
    (VISIBILITY_BY_KEY[self.notification_type] == VISIBILITY[:CC_NOTIFICATION])
  end

  def can_turn_off_for_agent?
    !AGENT_MANDATORY_LIST.include?(self.token)
  end

  def can_turn_off_for_requester?
    !REQUESTER_MANDATORY_LIST.include?(self.token)
  end

  def self.agent_visible_template?(notification_type)
    ([ VISIBILITY[:AGENT_AND_REQUESTER], VISIBILITY[:AGENT_ONLY] ].include? VISIBILITY_BY_KEY[notification_type])
  end

  def self.requester_visible_template?(notification_type)
    ([ VISIBILITY[:AGENT_AND_REQUESTER], VISIBILITY[:REQUESTER_ONLY] ].include? VISIBILITY_BY_KEY[notification_type])
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

  def agent_notification?
    agent_notification && allowed_in_thread_local?(:agent_notification)
  end
  
  def requester_notification?
    requester_notification && allowed_in_thread_local?(:requester_notification)
  end

  def toggle_requester_notification enable
    self.update_attribute(:requester_notification, enable)
  end

  def toggle_agent_notification enable
    self.update_attribute(:agent_notification, enable)
  end

  def requester_notification_updated?
    previous_changes.has_key?(:requester_notification)
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

  def get_internal_agent_template(agent)
    subject, description = get_agent_template(agent)
    [replace_agent_group_placeholders(subject), replace_agent_group_placeholders(description)]
  end

  def get_internal_agent_plain_template(agent)
    template = get_agent_plain_template(agent)
    replace_agent_group_placeholders(template)
  end

  def replace_agent_group_placeholders(content)
    content = content.gsub("{{ticket.agent.", "{{ticket.internal_agent.")
    content.gsub("{{ticket.group.", "{{ticket.internal_group.")
  end

  def return_template(type,language)
    if (type == DynamicNotificationTemplate::CATEGORIES[:requester])
      dynamic_notification_templates.requester_template.for_language(language)
    else
      dynamic_notification_templates.agent_template.for_language(language)
    end
  end

  def get_requester_template(requester)
    if not_dynamic_content?(requester)
      template = [ requester_subject_template, requester_template ]
    else  
      d_template = dynamic_notification_templates.requester_template.active.for_language(requester.language).first
      d_template ? [ d_template.subject, d_template.description ] : [ requester_subject_template, requester_template ]
    end
  end

  def get_reply_template(user)
    if not_dynamic_content?(user)
      template =requester_template
    else
       d_template = dynamic_notification_templates.requester_template.active.for_language(user.language).first
       d_template ? d_template.description : requester_template
    end     
  end

  def get_forward_template(user)
    if not_dynamic_content?(user)
      template =requester_template
    else
       d_template = dynamic_notification_templates.requester_template.active.for_language(user.language).first
       d_template ? d_template.description : requester_template
    end
  end

  def self.disable_notification (account)
    Thread.current["notifications_#{account.id}"] = EmailNotification::DISABLE_NOTIFICATION  
  end

  def fetch_template
    if self.reply_template? or self.cc_notification? or self.forward_template?
      "requester_template"
    end
  end

  def bcc_disabled?
    BCC_DISABLED_NOTIFICATIONS.include?(self.notification_type)
  end

  def not_dynamic_content?(user)
    user.language.nil? || user.account.language == user.language || !user.account.features?(:dynamic_content)
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
