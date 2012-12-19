require 'digest/md5'


class Helpdesk::Ticket < ActiveRecord::Base
  
  belongs_to_account

  include ActionController::UrlWriter
  include TicketConstants
  include Helpdesk::TicketModelExtension
  include Helpdesk::Ticketfields::TicketStatus
  include ParserUtil
  include BusinessRulesObserver
  include Mobile::Actions::Ticket
  include Gamification::GamificationUtil
  include RedisKeys

  SCHEMA_LESS_ATTRIBUTES = ["product_id","to_emails","product", "skip_notification", 
                            "header_info", "st_survey_rating", "trashed"]
  EMAIL_REGEX = /(\b[-a-zA-Z0-9.'’_%+]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}\b)/

  set_table_name "helpdesk_tickets"
  
  serialize :cc_email
  
  has_flexiblefields
  
  unhtml_it :description
  
  #by Shan temp
  attr_accessor :email, :name, :custom_field ,:customizer, :nscname, :twitter_id, :external_id, :requester_name, :meta_data, :disable_observer
  
  before_validation :populate_requester, :set_default_values
  
  before_create :assign_schema_less_attributes, :assign_email_config_and_product, :set_dueby, :save_ticket_states

  has_many :attachments,
    :as => :attachable,
    :class_name => 'Helpdesk::Attachment',
    :dependent => :destroy
  
  after_create :refresh_display_id, :create_meta_note

  before_update :assign_email_config, :load_ticket_status, :update_dueby
  
  before_save :update_ticket_changes

  after_save :save_custom_field

  after_commit_on_create :create_initial_activity,  :update_content_ids, :pass_thro_biz_rules,
    :support_score_on_create, :process_quests
  
  after_commit_on_update :update_ticket_states, :notify_on_update, :update_activity, 
    :stop_timesheet_timers, :fire_update_event, :support_score_on_update, 
    :process_quests, :publish_to_update_channel

  has_one :schema_less_ticket, :class_name => 'Helpdesk::SchemaLessTicket', :dependent => :destroy

  belongs_to :email_config
  belongs_to :group
 
  belongs_to :responder,
    :class_name => 'User',
    :conditions => ['users.user_role not in (?,?)',User::USER_ROLES_KEYS_BY_TOKEN[:customer],
    User::USER_ROLES_KEYS_BY_TOKEN[:client_manager]]

  belongs_to :requester,
    :class_name => 'User'
  

  belongs_to :sphinx_requester,
    :class_name => 'User',
    :foreign_key => 'requester_id',
    :conditions => 'helpdesk_tickets.account_id = users.account_id'

  

  has_many :notes, 
    :class_name => 'Helpdesk::Note',
    :as => 'notable',
    :dependent => :destroy

  has_many :public_notes,
    :class_name => 'Helpdesk::Note',
    :as => 'notable', :conditions => {:private =>  false, :deleted => false}
    
  has_many :sphinx_notes, 
    :class_name => 'Helpdesk::Note',
    :conditions => 'helpdesk_tickets.account_id = helpdesk_notes.account_id',
    :as => 'notable'
    
  has_many :activities,
    :class_name => 'Helpdesk::Activity',
    :as => 'notable',
    :dependent => :destroy

  has_many :reminders, 
    :class_name => 'Helpdesk::Reminder',
    :dependent => :destroy

  has_many :subscriptions, 
    :class_name => 'Helpdesk::Subscription',
    :dependent => :destroy

  has_many :tag_uses,
    :as => :taggable,
    :class_name => 'Helpdesk::TagUse',
    :dependent => :destroy

  has_many :tags, 
    :class_name => 'Helpdesk::Tag',
    :through => :tag_uses

  has_many :ticket_issues,
    :class_name => 'Helpdesk::TicketIssue',
    :dependent => :destroy

  has_many :issues, 
    :class_name => 'Helpdesk::Issue',
    :through => :ticket_issues
    
  has_one :tweet,
    :as => :tweetable,
    :class_name => 'Social::Tweet',
    :dependent => :destroy
  
  has_one :fb_post,
    :as => :postable,
    :class_name => 'Social::FbPost',
    :dependent => :destroy
    
  has_one :ticket_states, :class_name =>'Helpdesk::TicketState',:dependent => :destroy
  delegate :closed_at, :resolved_at, :to => :ticket_states, :allow_nil => true
  
  belongs_to :ticket_status, :class_name =>'Helpdesk::TicketStatus', :foreign_key => "status", :primary_key => "status_id"
  delegate :active?, :open?, :is_closed, :closed?, :resolved?, :pending?, :onhold?, :onhold_and_closed?, :to => :ticket_status, :allow_nil => true
  
  has_one :ticket_topic,:dependent => :destroy
  has_one :topic, :through => :ticket_topic
  
  has_many :survey_handles, :as => :surveyable, :dependent => :destroy
  has_many :survey_results, :as => :surveyable, :dependent => :destroy
  has_many :support_scores, :as => :scorable, :dependent => :destroy
  
  has_many :time_sheets , :class_name =>'Helpdesk::TimeSheet', :dependent => :destroy, :order => "executed_at"

  attr_protected :attachments #by Shan - need to check..
  
  accepts_nested_attributes_for :tweet, :fb_post
  
  named_scope :created_at_inside, lambda { |start, stop|
          { :conditions => [" helpdesk_tickets.created_at >= ? and helpdesk_tickets.created_at <= ?", start, stop] }
        }
  named_scope :resolved_at_inside, lambda { |start, stop|
          { 
            :joins => [:ticket_states,:requester],
            :conditions => [" helpdesk_ticket_states.resolved_at >= ? and helpdesk_ticket_states.resolved_at <= ?", start, stop] }
        }

  named_scope :resolved_and_closed_tickets, :conditions => {:status => [RESOLVED,CLOSED]}
  
  named_scope :all_company_tickets,lambda { |customer| { 
        :joins => "INNER JOIN users ON users.id = helpdesk_tickets.requester_id and users.account_id = helpdesk_tickets.account_id ",
        :conditions => [" users.customer_id = ?",customer]
  } 
  }
  
  named_scope :company_tickets_resolved_on_time,lambda { |customer| { 
        :joins => "INNER JOIN users ON users.id = helpdesk_tickets.requester_id and users.account_id = helpdesk_tickets.account_id INNER JOIN helpdesk_ticket_states on helpdesk_tickets.id = helpdesk_ticket_states.ticket_id and helpdesk_tickets.account_id = helpdesk_ticket_states.account_id",
        :conditions => ["helpdesk_tickets.due_by >  helpdesk_ticket_states.resolved_at AND users.customer_id = ?",customer]
  } 
  }
  
   named_scope :resolved_on_time,
        :joins => "INNER JOIN helpdesk_ticket_states on helpdesk_tickets.id = helpdesk_ticket_states.ticket_id and helpdesk_tickets.account_id = helpdesk_ticket_states.account_id",
        :conditions => ["helpdesk_tickets.due_by >  helpdesk_ticket_states.resolved_at"]
   
  named_scope :first_call_resolution,
           :joins  => "INNER JOIN helpdesk_ticket_states on helpdesk_tickets.id = helpdesk_ticket_states.ticket_id and helpdesk_tickets.account_id = helpdesk_ticket_states.account_id",
           :conditions => ["(helpdesk_ticket_states.resolved_at is not null)  and  helpdesk_ticket_states.inbound_count = 1"]

  named_scope :company_first_call_resolution,lambda { |customer| { 
        :joins => "INNER JOIN users ON users.id = helpdesk_tickets.requester_id and users.account_id = helpdesk_tickets.account_id INNER JOIN helpdesk_ticket_states on helpdesk_tickets.id = helpdesk_ticket_states.ticket_id and helpdesk_tickets.account_id = helpdesk_ticket_states.account_id",
        :conditions => ["(helpdesk_ticket_states.resolved_at is not null)  and  helpdesk_ticket_states.inbound_count = 1 AND users.customer_id = ?",customer]
  } 
  }
        

  named_scope :newest, lambda { |num| { :limit => num, :order => 'created_at DESC' } }
  named_scope :updated_in, lambda { |duration| { :conditions => [ 
    "helpdesk_tickets.updated_at > ?", duration ] } }
  
  named_scope :created_in, lambda { |duration| { :conditions => [ 
    "helpdesk_tickets.created_at > ?", duration ] } }
 
  named_scope :visible, :conditions => ["spam=? AND helpdesk_tickets.deleted=? AND status > 0", false, false] 
  named_scope :unresolved, :conditions => ["status not in (#{RESOLVED}, #{CLOSED})"]
  named_scope :assigned_to, lambda { |agent| { :conditions => ["responder_id=?", agent.id] } }
  named_scope :requester_active, lambda { |user| { :conditions => 
    [ "requester_id=? ",
      user.id ], :order => 'created_at DESC' } }
  named_scope :requester_completed, lambda { |user| { :conditions => 
    [ "requester_id=? and status in (#{RESOLVED}, #{CLOSED})",
      user.id ] } }
      
  named_scope :permissible , lambda { |user| { :conditions => agent_permission(user)}  unless user.customer? }
 
  named_scope :latest_tickets, lambda {|updated_at| {:conditions => ["helpdesk_tickets.updated_at > ?", updated_at]}}

  named_scope :with_tag_names, lambda { |tag_names| {
            :joins => :tags,
            :select => "helpdesk_tickets.id", 
            :conditions => ["helpdesk_tags.name in (?)",tag_names] } 
  }            
  
  def self.agent_permission user
    
    permissions = {:all_tickets => [] , 
                   :group_tickets => ["group_id in (?) OR responder_id=?", user.agent_groups.collect{|ag| ag.group_id}.insert(0,0), user.id] , 
                   :assigned_tickets =>["responder_id=?", user.id] }
                  
     return permissions[Agent::PERMISSION_TOKENS_BY_KEY[user.agent.ticket_permission]]
  end
  
  def agent_permission_condition user
     permissions = {:all_tickets => "" , 
                   :group_tickets => " AND (group_id in (#{user.agent_groups.collect{|ag| ag.group_id}.insert(0,0)}) OR responder_id= #{user.id}) " , 
                   :assigned_tickets => " AND (responder_id= #{user.id}) " }
                  
     return permissions[Agent::PERMISSION_TOKENS_BY_KEY[user.agent.ticket_permission]]
  end
  
  def get_default_filter_permissible_conditions user
    
     permissions = {:all_tickets => "" , 
                   :group_tickets => " [{\"condition\": \"responder_id\", \"operator\": \"is_in\", \"value\": \"#{user.id}\"}, {\"condition\": \"group_id\", \"operator\": \"is_in\", \"value\": \"#{user.agent_groups.collect{|ag| ag.group_id}.insert(0,0)}\"}] " , 
                   :assigned_tickets => "[{\"condition\": \"responder_id\", \"operator\": \"is_in\", \"value\": \"#{user.id}\"}]"}
                  
     return permissions[Agent::PERMISSION_TOKENS_BY_KEY[user.agent.ticket_permission]]
    
  end
  
  #Sphinx configuration starts
  define_index do
    
    indexes :display_id, :sortable => true
    indexes :subject, :sortable => true
    indexes description
    indexes sphinx_notes.body, :as => :note
    
    has account_id, deleted, responder_id, group_id, requester_id, status
    has sphinx_requester.customer_id, :as => :customer_id
    has SearchUtil::DEFAULT_SEARCH_VALUE, :as => :visibility, :type => :integer
    has SearchUtil::DEFAULT_SEARCH_VALUE, :as => :customer_ids, :type => :integer

    where "helpdesk_tickets.spam=0 and helpdesk_tickets.deleted = 0"

    #set_property :delta => Sphinx::TicketDelta

    set_property :field_weights => {
      :display_id   => 10,
      :subject      => 10,
      :description  => 5,
      :note         => 3
     }
  end
  #Sphinx configuration ends here..

  #For custom_fields
  COLUMNTYPES = [
    [ "number",       "text_field",   "text" ], 
    [ "text",         "text_field",   "text"], 
    [ "checkbox",     "check_box" ,   "checkbox"], 
    [ "dropdown",     "select"    ,   "select"], 
  ]

  COLUMN_TYPE_BY_KEY = Hash[*COLUMNTYPES.map { |i| [i[0], i[1]] }.flatten]
  COLUMN_CLASS_BY_KEY = Hash[*COLUMNTYPES.map { |i| [i[0], i[2]] }.flatten]

  #validates_presence_of :name, :source, :id_token, :access_token, :status, :source
  #validates_length_of :email, :in => 5..320, :allow_nil => false, :allow_blank => false
  #validates_presence_of :responder_id
  validates_presence_of :requester_id, :message => "should be a valid email address"
  validates_numericality_of :source, :status, :only_integer => true
  validates_numericality_of :requester_id, :responder_id, :only_integer => true, :allow_nil => true
  validates_inclusion_of :source, :in => 1..SOURCES.size
  validates_inclusion_of :priority, :in => PRIORITY_TOKEN_BY_KEY.keys, :message=>"should be a valid priority" #for api
  #validates_inclusion_of :status, :in => STATUS_KEYS_BY_TOKEN.values.min..STATUS_KEYS_BY_TOKEN.values.max
  #validates_format_of :email, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i, 
  #:allow_nil => false, :allow_blank => false
  
  def set_default_values
    self.status = OPEN unless (Helpdesk::TicketStatus.status_names_by_key(account).key?(self.status) or ticket_status.try(:deleted?))
    self.source = TicketConstants::SOURCE_KEYS_BY_TOKEN[:portal] if self.source == 0
    self.ticket_type ||= account.ticket_type_values.first.value
    self.subject ||= ''
    self.group_id ||= email_config.group_id unless email_config.nil?
    #self.description = subject if description.blank?
  end
  
  
  
  def to_param 
    display_id ? display_id.to_s : nil
  end 

  def self.find_by_param(token, account)
    find_by_display_id_and_account_id(token, account.id)
  end

  def freshness #Need to clean it up later.. by Shan
    responder ? :reply : :new
  end

  def status=(val)
    self[:status] = (Helpdesk::TicketStatus.status_keys_by_name(account)[val] unless account.nil?) || val
  end

  def status_name
    Helpdesk::TicketStatus.translate_status_name(ticket_status)
  end

  def requester_status_name
    Helpdesk::TicketStatus.translate_status_name(ticket_status, "customer_display_name")
  end

  def source_name
    SOURCE_NAMES_BY_KEY(source)
  end

   def is_twitter?
    (tweet) and (!account.twitter_handles.blank?) 
  end
  alias :is_twitter :is_twitter?

  def is_facebook?
     (fb_post) and (fb_post.facebook_page) 
  end
  alias :is_facebook :is_facebook?
 
 def is_fb_message?
   (fb_post) and (fb_post.facebook_page) and (fb_post.message?)
 end
 alias :is_fb_message :is_fb_message?


  def is_fb_wall_post?
    (fb_post) and (fb_post.facebook_page) and (fb_post.post?)
  end
  
  def priority=(val)
    self[:priority] = PRIORITY_KEYS_BY_TOKEN[val] || val
  end

  def priority_name
    PRIORITY_NAMES_BY_KEY[priority]
  end
  
  def priority_key
    PRIORITY_TOKEN_BY_KEY[priority]
  end

  def create_activity(user, description, activity_data = {}, short_descr = nil)
    activities.create(
      :description => description,
      :short_descr => short_descr,
      :account => account,
      :user => user,
      :activity_data => activity_data
    )
  end
  
  def create_initial_activity
   unless spam?
    create_activity(requester, 'activities.tickets.new_ticket.long', {},
                              'activities.tickets.new_ticket.short')
   end
  end

  def source=(val)
    self[:source] = SOURCE_KEYS_BY_TOKEN[val] || val
  end

  def source_name
    SOURCE_NAMES_BY_KEY[source]
  end

  def nickname
    subject
  end
  
  def requester_info
    requester.get_info if requester
  end
  
  def requester_has_email?
    (requester) and (!requester.email.blank?)
  end

  def encode_display_id
    "[#{ticket_id_delimiter}#{display_id}]"
  end

  def conversation(page = nil, no_of_records = 5, includes=[])
    notes.visible.exclude_source('meta').newest_first.paginate(:include => includes ,:page => page, :per_page => no_of_records)
  end

  def conversation_count(page = nil, no_of_records = 5)
    notes.visible.exclude_source('meta').size
  end

  def train(category)
    self[:trained] = true
    self[:spam] = (category == :spam)
  end
    
  def self.extract_id_token(text, delimeter)
    pieces = text.match(Regexp.new("\\[#{delimeter}([0-9]*)\\]")) #by Shan changed to just numeric
    pieces && pieces[1]
  end

  def load_ticket_status
    if status_changed?
      self.ticket_status = account.ticket_status_values.find_by_status_id(status)
    end
  end

  #shihab-- date format may need to handle later. methode will set both due_by and first_resp
  def update_dueby
    set_dueby if priority_changed?
    set_dueby(true) if status_changed?
  end
  
  def set_dueby(start_sla_timer=nil)
    set_account_time_zone   
    self.priority = PRIORITY_KEYS_BY_TOKEN[:low] if priority.nil?
    
    sla_policy_id = requester.customer.sla_policy_id unless requester.customer.nil?
    sla_policy_id = Helpdesk::SlaPolicy.find_by_account_id_and_is_default(account_id, true) if sla_policy_id.nil?     
    sla_detail = Helpdesk::SlaDetail.find(:first, :conditions =>{:sla_policy_id =>sla_policy_id, :priority =>self.priority})
    
    set_dueby_on_priority_change(sla_detail) if start_sla_timer.nil?
    set_dueby_on_status_change(sla_detail) unless start_sla_timer.nil? 
    
    set_user_time_zone if User.current
    logger.debug "sla_detail_id :: #{sla_detail.id} :: due_by::#{self.due_by} and fr_due:: #{self.frDueBy} "   
  end

  def set_account_time_zone  
    self.account.make_current
    Time.zone = self.account.time_zone    
  end
 
  def set_user_time_zone 
    Time.zone = User.current.time_zone  
  end
  
  def refresh_display_id #by Shan temp
    if display_id.nil?
      self.display_id = Helpdesk::Ticket.find_by_id(id).display_id #by Shan hack need to revisit about self as well.
    end
  end

  def create_meta_note
    if meta_data.present?  # Added for storing metadata from MobiHelp
      self.notes.create(
        :body => meta_data.map { |k, v| "#{k}: #{v}" }.join("\n"),
        :private => true,
        :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['meta'],
        :account_id => self.account.id,
        :user_id => self.requester.id
      )
    end
  end

  def autoreply     
    return if spam? || deleted? || self.skip_notification?
    notify_by_email(EmailNotification::NEW_TICKET)
    notify_by_email_without_delay(EmailNotification::TICKET_ASSIGNED_TO_GROUP) if group_id and !group_id_changed?
    notify_by_email_without_delay(EmailNotification::TICKET_ASSIGNED_TO_AGENT) if responder_id and !responder_id_changed?
    
    unless status_changed?
      return notify_by_email_without_delay(EmailNotification::TICKET_RESOLVED) if resolved?
      return notify_by_email_without_delay(EmailNotification::TICKET_CLOSED) if closed?
    end
  end

  def out_of_office?
    TicketConstants::OUT_OF_OFF_SUBJECTS.any? { |s| subject.downcase.include?(s) }
  end
  
  def included_in_fwd_emails?(from_email)
    (cc_email_hash) and  (cc_email_hash[:fwd_emails].any? {|email| email.include?(from_email) }) 
  end
  
  def included_in_cc?(from_email)
    (cc_email_hash) and  ((cc_email_hash[:cc_emails].any? {|email| email.include?(from_email) }) or 
                     (cc_email_hash[:fwd_emails].any? {|email| email.include?(from_email) }))
  end
  
  def notify_on_update
    return if spam? || deleted?
    notify_by_email(EmailNotification::TICKET_ASSIGNED_TO_GROUP) if (@ticket_changes.key?(:group_id) && group)
    if (@ticket_changes.key?(:responder_id) && responder && responder != User.current)
      notify_by_email(EmailNotification::TICKET_ASSIGNED_TO_AGENT)
    end
    
    if @ticket_changes.key?(:status)
      return notify_by_email(EmailNotification::TICKET_RESOLVED) if (status == RESOLVED)
      return notify_by_email(EmailNotification::TICKET_CLOSED) if (status == CLOSED)
    end
  end
  
  def save_ticket_states
    self.ticket_states = Helpdesk::TicketState.new
    ticket_states.account_id = account_id
    ticket_states.assigned_at=Time.zone.now if responder_id
    ticket_states.first_assigned_at = Time.zone.now if responder_id
    ticket_states.pending_since=Time.zone.now if (status == PENDING)
    ticket_states.set_resolved_at_state if (status == RESOLVED)
    ticket_states.resolved_at ||= ticket_states.set_closed_at_state if (status == CLOSED)
    ticket_states.status_updated_at = Time.zone.now
    ticket_states.sla_timer_stopped_at = Time.zone.now if (ticket_status.stop_sla_timer?)
  end

  def update_ticket_states 
    
    ticket_states.assigned_at=Time.zone.now if (@ticket_changes.key?(:responder_id) && responder)    
    if (@ticket_changes.key?(:responder_id) && @ticket_changes[:responder_id][0].nil? && responder)
      ticket_states.first_assigned_at = Time.zone.now
    end
    
    if @ticket_changes.key?(:status)
      if (status == OPEN)
        ticket_states.opened_at=Time.zone.now
        ticket_states.reset_tkt_states
      end
      
      ticket_states.pending_since=Time.zone.now if (status == PENDING)
      ticket_states.set_resolved_at_state if (status == RESOLVED)
      ticket_states.set_closed_at_state if closed?
      
      ticket_states.status_updated_at = Time.zone.now
      if(ticket_status.stop_sla_timer)
        ticket_states.sla_timer_stopped_at ||= Time.zone.now 
      else
        ticket_states.sla_timer_stopped_at = nil
      end
    end    
    ticket_states.save
  end
  
  def notify_by_email_without_delay(notification_type)    
    Helpdesk::TicketNotifier.notify_by_email(notification_type, self) if notify_enabled?(notification_type)
  end
  
  def notify_by_email(notification_type)    
    Helpdesk::TicketNotifier.send_later(:notify_by_email, notification_type, self) if notify_enabled?(notification_type)
  end
  
  def notify_enabled?(notification_type)
    e_notification = account.email_notifications.find_by_notification_type(notification_type)
    e_notification.requester_notification? or e_notification.agent_notification?
  end
  
  def custom_fields
    @custom_fields = FlexifieldDef.all(:include => 
      [:flexifield_def_entries =>:flexifield_picklist_vals], 
      :conditions => ['account_id=? AND module=?',account_id,'Ticket'] ) 
  end

  def ticket_id_delimiter
    delimiter = account.ticket_id_delimiter
    delimiter = delimiter.blank? ? '#' : delimiter
  end
  
  def to_s
    begin
    "#{subject} (##{display_id})"
    rescue ActiveRecord::MissingAttributeError
      "#{id}"
    end
  end
  
  def self.search_display(ticket)
    "#{ticket.excerpts.subject} (##{ticket.excerpts.display_id})"
  end
  
  def friendly_reply_email
    email_config ? email_config.friendly_email : account.default_friendly_email
  end

  def friendly_reply_email_personalize(user_name)
    email_config ? email_config.friendly_email_personalize(user_name) : account.default_friendly_email_personalize(user_name)
  end
  
  def reply_email
    email_config ? email_config.reply_email : account.default_email
  end
  
  def reply_name
    email_config ? email_config.name : account.primary_email_config.name
  end

  #Some hackish things for virtual agent rules.
  def tag_names
    tags.collect { |tag| tag.name }
  end
  
  def subject_or_description
    [subject, description]
  end
  
  def from_email
    requester.email if requester
  end
  
  def contact_name
    requester.name if requester
  end
  
  def company_name
    requester.customer.name if (requester && requester.customer)
  end
  #virtual agent things end here..
  
  def pass_thro_biz_rules
     send_later(:delayed_rule_check) unless import_id
  end
  
  def delayed_rule_check
   begin
    evaluate_on = check_rules     
    update_custom_field evaluate_on unless evaluate_on.nil?
    autoreply
   rescue Exception => e #better to write some rescue code 
    NewRelic::Agent.notice_error(e)
   end
    save #Should move this to unless block.. by Shan
  end
 
  def check_rules
    load_flexifield 
    evaluate_on = self  
    account.va_rules.each do |vr|
      evaluate_on= vr.pass_through(self)
      return evaluate_on unless evaluate_on.nil?
    end  
    return evaluate_on       
  end
  
  def load_flexifield 
    flexi_arr = Hash.new
    self.ff_aliases.each do |label|    
      value = self.get_ff_value(label.to_sym())    
      flexi_arr[label] = value
      self.write_attribute label, value
    end
    
    self.custom_field = flexi_arr
  end
  
  def update_custom_field  evaluate_on
    flexi_field = evaluate_on.custom_field      
    evaluate_on.custom_field.each do |key,value|    
      flexi_field[key] = evaluate_on.read_attribute(key)      
    end
    
    ff_def_id = FlexifieldDef.find_by_account_id(evaluate_on.account_id).id    
    evaluate_on.ff_def = ff_def_id       
    unless flexi_field.nil?     
      evaluate_on.assign_ff_values flexi_field    
    end
  end
  
  def save_custom_field   
    ff_def_id = FlexifieldDef.find_by_account_id(self.account_id).id    
    self.ff_def = ff_def_id
    self.flexifield.account_id = account_id
    unless self.custom_field.nil?          
      self.assign_ff_values self.custom_field    
    end
  end
  
  #To use liquid template...
  #Might be darn expensive db queries, need to revisit - shan.
  def to_liquid

    Helpdesk::TicketDrop.new self
    
  end

  def url_protocol
    account.ssl_enabled? ? 'https' : 'http'
  end
  
  def description_with_attachments
    attachments.empty? ? description_html : 
        "#{description_html}\n\nTicket attachments :\n#{liquidize_attachments(attachments)}\n"
  end
  
  def liquidize_attachments(attachments)
    attachments.each_with_index.map { |a, i| 
      "#{i+1}. <a href='#{helpdesk_attachment_url(a, :host => portal_host)}'>#{a.content_file_name}</a>"
      }.join("<br />") #Not a smart way for sure, but donno how to do this in RedCloth?
  end
  
  def latest_public_comment
    notes.visible.public.newest_first.first
  end
  
  def liquidize_comment(comm)
    if comm
      c_descr = "#{comm.user ? comm.user.name : 'System'} : #{comm.body_html}"
      unless comm.attachments.empty?
        c_descr = "#{c_descr}\n\nAttachments :\n#{liquidize_attachments(comm.attachments)}\n"
      end
      c_descr
    end
  end
  #Liquid ends here
  
  def respond_to?(attribute)
    return false if [:to_ary].include?(attribute.to_sym)    
    # Array.flatten calls respond_to?(:to_ary) for each object.
    #  Rails calls array's flatten method on query result's array object. This was added to fix that.

    super(attribute) || SCHEMA_LESS_ATTRIBUTES.include?(attribute.to_s.chomp("=").chomp("?")) || 
      ticket_states.respond_to?(attribute) || custom_field_aliases.include?(attribute.to_s.chomp("=").chomp("?"))
  end

  def schema_less_attributes(attribute, args)
    logger.debug "schema_less_attributes - method_missing :: args is #{args} and attribute :: #{attribute}"
    build_schema_less_ticket unless schema_less_ticket
    args = args.first if args && args.is_a?(Array) 
    (attribute.to_s.include? '=') ? schema_less_ticket.send(attribute, args) : schema_less_ticket.send(attribute)
  end

  def custom_field_attribute attribute, args    
    logger.debug "method_missing :: custom_field_attribute  args is #{args.inspect}  and attribute: #{attribute}"
    
    load_flexifield if custom_field.nil?
    attribute = attribute.to_s
    return custom_field[attribute] unless attribute.include?("=")
      
    ff_def_id = FlexifieldDef.find_by_account_id(self.account_id).id
    field = attribute.to_s.chomp("=")
    args = args.first if !args.blank? && args.is_a?(Array) 
    self.ff_def = ff_def_id
    custom_field[field] = args
  end

  def method_missing(method, *args, &block)
    begin
      super
    rescue NoMethodError => e
      logger.debug "method_missing :: args is #{args.inspect} and method:: #{method} "

      return schema_less_attributes(method, args) if SCHEMA_LESS_ATTRIBUTES.include?(method.to_s.chomp("=").chomp("?"))
      return ticket_states.send(method) if ticket_states.respond_to?(method)
      return custom_field_attribute(method, args) if self.ff_aliases.include?(method.to_s.chomp("=").chomp("?"))
      raise e
    end
  end

  def requester_name
    requester.name || requester_info
  end

  def need_attention
    active? and ticket_states.need_attention
  end

  def to_json(options = {}, deep=true)
    options[:methods] = [:status_name, :requester_status_name, :priority_name, :source_name, :requester_name,:responder_name] unless options.has_key?(:methods)
    unless options[:basic].blank? # basic prop is made sure to be set to true from controllers always.
      options[:only] = [:display_id,:subject,:deleted]
      json_str = super options
      return json_str
    end
    if deep
      self.load_flexifield
      self[:notes] = self.notes
      options[:include] = [:attachments]
      options[:except] = [:account_id,:import_id]
      options[:methods].push(:custom_field)
    end
    json_str = super options
    json_str.sub("\"ticket\"","\"helpdesk_ticket\"")
  end


  def to_xml(options = {})
    options[:indent] ||= 2
    xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
    xml.instruct! unless options[:skip_instruct]

    unless options[:basic].blank? #to give only the basic properties[basic prop set from 
      return super(:builder =>xml,:skip_instruct => true,:only =>[:display_id,:subject,:deleted],
          :methods=>[:status_name, :requester_status_name, :priority_name, :source_name, :requester_name,:responder_name])
    end
    super(:builder => xml, :skip_instruct => true,:include => [:notes,:attachments],:except => [:account_id,:import_id], 
      :methods=>[:status_name, :requester_status_name, :priority_name, :source_name, :requester_name,:responder_name]) do |xml|
      xml.custom_field do
        self.account.ticket_fields.custom_fields.each do |field|
          begin
           value = send(field.name) 
           xml.tag!(field.name.gsub(/[^0-9A-Za-z_]/, ''), value) unless value.blank?

           if(field.field_type == "nested_field")
              field.nested_ticket_fields.each do |nested_field|
                nested_field_value = send(nested_field.name)
                xml.tag!(nested_field.name.gsub(/[^0-9A-Za-z_]/, ''), nested_field_value) unless nested_field_value.blank?
              end
           end
         
         rescue
           end 
        end
      end
     end
  end
  
  def fetch_twitter_handle
    twt_handles = self.product ? self.product.twitter_handles : account.twitter_handles
    twt_handles.first.id unless twt_handles.blank?
  end
  
  def portal_host
    (self.product && !self.product.portal_url.blank?) ? self.product.portal_url : account.host
  end
  
  def portal_name
    (self.product && self.product.portal_name) ? self.product.portal_name : account.portal_name
  end
  
  def update_activity
    @ticket_changes.each_key do |attr|
      send(ACTIVITY_HASH[attr.to_sym()]) if ACTIVITY_HASH.has_key?(attr.to_sym())
    end
  end
  
   
   def group_name
      group.nil? ? "No Group" : group.name
    end
    
   def product_name
      self.product ? self.product.name : "No Product"
   end
   
   def responder_name
      responder.nil? ? "No Agent" : responder.name
    end
    
    def customer_name
      requester.customer.nil? ? "No company" : requester.customer.name
    end
    
    def priority_name
      PRIORITY_NAMES_BY_KEY[priority]
    end
    
   def stop_timesheet_timers
    if @ticket_changes.key?(:status) && [RESOLVED, CLOSED].include?(status)
       running_timesheets =  time_sheets.find(:all , :conditions =>{:timer_running => true})
       running_timesheets.each{|t| t.stop_timer}
    end
   end

  def cc_email_hash
    if cc_email.is_a?(Array)     
      {:cc_emails => cc_email, :fwd_emails => []}
    else
      cc_email
    end
  end

  def reply_to_all_emails
    emails_hash = cc_email_hash
    return [] if emails_hash.nil?
    to_emails_array = []
    cc_emails_array = emails_hash[:cc_emails].blank? ? [] : emails_hash[:cc_emails]
    to_emails_array = (self.to_emails || []).clone

    reply_to_all_emails = (cc_emails_array + to_emails_array).uniq

    account.support_emails.each do |support_email|
      reply_to_all_emails.delete_if {|to_email| ((parse_email_text(support_email)[:email]).casecmp(parse_email_text(to_email.strip)[:email]) == 0)}
    end

    reply_to_all_emails
  end  

  def selected_reply_email
    account.pass_through_enabled? ? friendly_reply_email : account.default_friendly_email
  end

  def can_access?(user)
    if user.agent.blank?
      return true if self.requester_id==user.id
      if user.client_manager?
        return self.requester.customer_id == user.customer_id
      end
    else
      return true if user.agent.all_ticket_permission || self.responder_id==user.id
      if user.agent.group_ticket_permission          
        user.agent_groups.each do |ag|                   
          return true if self.group_id == ag.group_id
        end                           
      end
    end
    return false
  end


  private

    
    def sphinx_data_changed?
      description_html_changed? || requester_id_changed? || responder_id_changed? || group_id_changed? || deleted_changed?
    end

    def custom_field_aliases
      return flexifield ? ff_aliases : account.flexi_field_defs.first.ff_aliases
    end

    def update_content_ids
      header = self.header_info
      return if attachments.empty? or header.nil? or header[:content_ids].blank?
      
      description_updated = false
      attachments.each do |attach| 
        content_id = header[:content_ids][attach.content_file_name]
        self.description_html.sub!("cid:#{content_id}", attach.content.url) if content_id
        description_updated = true
      end

      # For rails 2.3.8 this was the only i found with which we can update an attribute without triggering any after or before callbacks
      Helpdesk::Ticket.update_all("description_html= #{ActiveRecord::Base.connection.quote(description_html)}", ["id=? and account_id=?", id, account_id]) \
          if description_updated
    end

    def create_source_activity
      create_activity(User.current, 'activities.tickets.source_change.long',
          {'source_name' => source_name}, 'activities.tickets.source_change.short')
    end
  
    def create_product_activity
      unless self.product
        create_activity(User.current, 'activities.tickets.product_change_none.long', {}, 
                                   'activities.tickets.product_change_none.short')
      else
        create_activity(User.current, 'activities.tickets.product_change.long',
          {'product_name' => self.product.name}, 'activities.tickets.product_change.short')
      end
    
    end
  
    def create_ticket_type_activity
       create_activity(User.current, 'activities.tickets.ticket_type_change.long',
          {'ticket_type' => ticket_type}, 'activities.tickets.ticket_type_change.short')
    end
  
    def create_group_activity
      unless group
          create_activity(User.current, 'activities.tickets.group_change_none.long', {}, 
                                   'activities.tickets.group_change_none.short')
      else
      create_activity(User.current, 'activities.tickets.group_change.long',
          {'group_name' => group.name}, 'activities.tickets.group_change.short')
      end
    end
  
    def create_status_activity
      create_activity(User.current, 'activities.tickets.status_change.long',
          {'status_name' => Helpdesk::TicketStatus.translate_status_name(ticket_status, "name")}, 'activities.tickets.status_change.short')
    end
  
    def create_priority_activity
       create_activity(User.current, 'activities.tickets.priority_change.long', 
          {'priority_name' => priority_name}, 'activities.tickets.priority_change.short')
 
    end

    def create_deleted_activity
      if deleted
        create_activity(User.current, 'activities.tickets.deleted.long',
         {'ticket_id' => display_id}, 'activities.tickets.deleted.short')
      else
        create_activity(User.current, 'activities.tickets.restored.long',
         {'ticket_id' => display_id}, 'activities.tickets.restored.short')
      end 
    end
  
    def create_assigned_activity
      unless responder
        create_activity(User.current, 'activities.tickets.assigned_to_nobody.long', {}, 
                                   'activities.tickets.assigned_to_nobody.short')
      else
        create_activity(User.current, 
          @ticket_changes[:responder_id][0].nil? ? 'activities.tickets.assigned.long' : 'activities.tickets.reassigned.long', 
            {'eval_args' => {'responder_path' => ['responder_path', 
              {'id' => responder.id, 'name' => responder.name}]}}, 
            'activities.tickets.assigned.short')
      end
    end
    
    def support_score_on_create
      add_support_score if gamification_feature?(account) && !active?
    end
    
    def support_score_on_update
      return unless gamification_feature?(account)

      if (reopened_now? or (@ticket_changes.key?(:deleted) && deleted?))
        Resque.enqueue(Gamification::Scoreboard::ProcessTicketScore, { :id => id, 
                :account_id => account_id,
                :remove_score => true })
      elsif resolved_now?
        add_support_score
      end
    end    

    def add_support_score
      Resque.enqueue(Gamification::Scoreboard::ProcessTicketScore, { :id => id, 
                :account_id => account_id,
                :fcr =>  ticket_states.first_call_resolution?,
                :resolved_at_time => ticket_states.resolved_at,
                :remove_score => false }) unless ticket_states.resolved_at.nil?
    end

    def update_ticket_changes
      @ticket_changes = self.changes.clone
      @ticket_changes.merge!(schema_less_ticket.changes.clone)
      @ticket_changes.symbolize_keys!
    end
    
    #Temporary move of quest processing from observer - Shan
    def process_quests
      if gamification_feature?(account)
  			process_available_quests
  			rollback_achieved_quests
  		end
    end
    
    def process_available_quests
  		if responder and resolved_now?
  			Resque.enqueue(Gamification::Quests::ProcessTicketQuests, { :id => id, 
  							:account_id => account_id })
  		end
  	end

  	def rollback_achieved_quests
  		if responder and reopened_now?
  			Resque.enqueue(Gamification::Quests::ProcessTicketQuests, { :id => id, 
  							:account_id => account_id, :rollback => true,
  							:resolved_time_was => ticket_states.resolved_time_was })
  		end
  	end

  	def resolved_now?
      @ticket_changes.key?(:status) && ((resolved? && @ticket_changes[:status][0] != CLOSED) || 
            (closed? && @ticket_changes[:status][0] != RESOLVED))
  	end

  	def reopened_now?
      @ticket_changes.key?(:status) && (active? && 
                      [RESOLVED, CLOSED].include?(@ticket_changes[:status][0]))
  	end
    #Quest processing ends here..

    def parse_email(email)
      if email =~ /(.+) <(.+?)>/
        name = $1
        email = $2
      elsif email =~ /<(.+?)>/
        email = $1
      else email =~ EMAIL_REGEX
        email = $1
      end

      { :email => email, :name => name }
  end 

  def set_dueby_on_priority_change(sla_detail)
      created_time = self.created_at || Time.zone.now
      self.due_by = sla_detail.calculate_due_by_time_on_priority_change(created_time)      
      self.frDueBy = sla_detail.calculate_frDue_by_time_on_priority_change(created_time) 
  end

  def set_dueby_on_status_change(sla_detail)
    unless (ticket_status.stop_sla_timer or ticket_states.sla_timer_stopped_at.nil?)
      self.due_by = sla_detail.calculate_due_by_time_on_status_change(self)      
      self.frDueBy = sla_detail.calculate_frDue_by_time_on_status_change(self) 
    end
  end

    def assign_schema_less_attributes
      build_schema_less_ticket unless schema_less_ticket
      schema_less_ticket.account_id ||= account_id
    end

    def assign_email_config_and_product
      if email_config
        self.product = email_config.product
      elsif self.product
        self.email_config = self.product.primary_email_config
      end
    end

    def assign_email_config
      assign_schema_less_attributes unless schema_less_ticket
      if schema_less_ticket.changed.include?("product_id")
        if self.product
          self.email_config = self.product.primary_email_config if email_config.nil? || (email_config.product.nil? || (email_config.product.id != self.product.id))      
        else
          self.email_config = nil
        end
      end
      schema_less_ticket.save unless schema_less_ticket.changed.empty?
    end

    def publish_to_update_channel
      return unless account.features?(:agent_collision)
      agent_name = User.current ? User.current.name : ""
      message = HELPDESK_TICKET_UPDATED_NODE_MSG % {:ticket_id => self.id, :agent_name => agent_name, :type => "updated"}
      publish_to_channel("tickets:#{self.account.id}:#{self.id}", message)
    end

    def fire_update_event
      fire_event(:update) unless disable_observer
    end

    def populate_requester
      return if requester

      unless email.blank?
        name_email = parse_email email  #changed parse_email to return a hash
        self.email = name_email[:email]
        self.name = name_email[:name]
        @requester_name ||= self.name # for MobiHelp
      end

      self.requester = account.all_users.find_by_an_unique_id({ 
        :email => self.email, 
        :twitter_id => twitter_id,
        :external_id => external_id })
      
      create_requester unless requester
    end

    def create_requester
      if can_add_requester?
        portal = self.product.portal if self.product
        requester = account.users.new
        requester.signup!({:user => {
          :email => email , :twitter_id => twitter_id, :external_id => external_id,
          :name => name || twitter_id || @requester_name || external_id,
          :user_role => User::USER_ROLES_KEYS_BY_TOKEN[:customer], :active => email.blank? }}, 
          portal) # check @requester_name and active
        
        self.requester = requester
      end
    end

    def can_add_requester?
      email.present? || twitter_id.present? || external_id.present? 
    end

end

