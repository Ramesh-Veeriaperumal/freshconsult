require 'digest/md5'

class Helpdesk::Ticket < ActiveRecord::Base 
  include ActionController::UrlWriter
  include TicketConstants
  
  set_table_name "helpdesk_tickets"
  
  has_flexiblefields
  
  #by Shan temp
  attr_accessor :email, :custom_field ,:customizer, :nscname
  after_create :refresh_display_id, :autoreply,:save_custom_field ,:pass_thro_biz_rules 
  after_update :save_custom_field
  before_create :populate_requester,:save_ticket_states
  

  before_create :set_spam, :set_dueby
  before_update :set_dueby, :cache_old_model
  after_update  :notify_on_update
  
  belongs_to :account
  belongs_to :email_config
  belongs_to :group

  belongs_to :responder,
    :class_name => 'User'

  belongs_to :requester,
    :class_name => 'User'

  has_many :notes, 
    :class_name => 'Helpdesk::Note',
    :as => 'notable',
    :dependent => :destroy
    
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
    
  has_many :attachments,
    :as => :attachable,
    :class_name => 'Helpdesk::Attachment',
    :dependent => :destroy
    
  has_one :ticket_states , :class_name =>'Helpdesk::TicketState'

  attr_protected :attachments #by Shan - need to check..

  has_one :ticket_topic
  has_one :topic,:through => :ticket_topic
  
  named_scope :newest, lambda { |num| { :limit => num, :order => 'created_at DESC' } }
  named_scope :visible, :conditions => ["spam=? AND deleted=? AND status > 0", false, false] 

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
  validates_numericality_of :source, :status, :only_integer => true
  validates_numericality_of :requester_id, :responder_id, :only_integer => true, :allow_nil => true
  validates_inclusion_of :source, :in => 0..SOURCES.size-1
  validates_inclusion_of :status, :in => STATUS_KEYS_BY_TOKEN.values.min..STATUS_KEYS_BY_TOKEN.values.max
  #validates_format_of :email, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i, :allow_nil => false, :allow_blank => false

  def to_param 
    display_id ? display_id.to_s : nil
  end 

  def self.find_by_param(token, account)
    find_by_display_id_and_account_id(token, account.id)
  end

  def freshness
    return :new if !responder
    return :closed if status <= 0

    last_note = notes.find_by_private(false, :order => "created_at DESC")

    (last_note && last_note.incoming) ? :reply : :waiting
  end

  def status=(val)
    self[:status] = STATUS_KEYS_BY_TOKEN[val] || val
  end

  def status_name
    STATUS_NAMES_BY_KEY[status]
  end
  
  def priority=(val)
    self[:priority] = PRIORITY_KEYS_BY_TOKEN[val] || val
  end

  def priority_name
    PRIORITY_NAMES_BY_KEY[priority]
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

  def source=(val)
    self[:source] = SOURCE_KEYS_BY_TOKEN[val] || val
  end

  def source_name
    SOURCE_NAMES_BY_KEY[source]
  end

  def nickname
    subject
  end

  def encode_display_id
    "[##{display_id}]"
  end

  def train(category)   
    classifier.untrain(spam ? :spam : :ham, spam_text) if trained
    classifier.train(category, spam_text)
    classifier.save
    self[:trained] = true
    self[:spam] = (category == :spam)
  end
    
  def self.extract_id_token(text)
    pieces = text.match(/\[#([0-9]*)\]/) #by Shan changed to just numeric
    pieces && pieces[1]
  end

  def classifier
    @classifier ||= Helpdesk::Classifier.find_by_name("spam")
  end

  def set_spam
    self[:spam] ||= (classifier.category?(spam_text) == "Spam") if spam_text && !Helpdesk::SPAM_TRAINING_MODE
    true
  end

  def spam_text
    @spam_text ||= notes.empty? ? description : notes.find(:first).body
  end

  #shihab-- date format may need to handle later. methode will set both due_by and first_resp
   def set_dueby    
   
     createdTime = Time.zone.now   
     
     unless self.created_at.nil?       
       createdTime = self.created_at       
     end    
     
     self.priority = 1 if priority.nil?     
     
     sla_policy_id = nil     
     unless self.requester.customer.nil?     
      sla_policy_id = self.requester.customer.sla_policy_id     
     end      
     sla_policy_id = Helpdesk::SlaPolicy.find_by_account_id_and_is_default(account_id, true) if sla_policy_id.nil?     
     sla_detail = Helpdesk::SlaDetail.find(:first , :conditions =>{:sla_policy_id =>sla_policy_id, :priority =>self.priority})
     
     
     
     if sla_detail.override_bhrs      
      self.due_by = createdTime + sla_detail.resolution_time.seconds      
      self.frDueBy = createdTime + sla_detail.response_time.seconds       
     else      
      self.due_by = (sla_detail.resolution_time).div(60).business_minute.after(createdTime)      
      self.frDueBy =  (sla_detail.response_time).div(60).business_minute.after(createdTime)     
    end
    
     logger.debug "sla_detail_id :: #{sla_detail.id} :: and createdTime : #{createdTime} due_by::#{self.due_by} and fr_due:: #{self.frDueBy} "   
  end
  
  def refresh_display_id #by Shan temp
    if display_id.nil?
      self.display_id = Helpdesk::Ticket.find_by_id(id).display_id #by Shan hack need to revisit about self as well.
    end
  end
  
  def populate_requester #by Shan temp
    if requester_id.nil? && !email.nil?
      @requester = User.find_by_email_and_account_id(email, account_id)
      if @requester.nil?
        @requester = User.new
        @requester.account_id = account_id
        @requester.signup!({:user => {:email => self.email, :name => '', :user_role => User::USER_ROLES_KEYS_BY_TOKEN[:customer]}})
      end
      
      self.requester = @requester
    end
  end
  
  def autoreply
    notify_by_email EmailNotification::NEW_TICKET
    
    notify_by_email(EmailNotification::TICKET_ASSIGNED_TO_GROUP) if group_id
    notify_by_email(EmailNotification::TICKET_ASSIGNED_TO_AGENT) if responder_id
    
    return notify_by_email(EmailNotification::TICKET_RESOLVED) if (status == STATUS_KEYS_BY_TOKEN[:resolved])
    return notify_by_email(EmailNotification::TICKET_CLOSED) if (status == STATUS_KEYS_BY_TOKEN[:closed])
  end
  
  def cache_old_model
    @old_ticket = Helpdesk::Ticket.find id
  end
  
  def notify_on_update
    notify_by_email(EmailNotification::TICKET_ASSIGNED_TO_GROUP) if (group_id != @old_ticket.group_id && group)
    notify_by_email(EmailNotification::TICKET_ASSIGNED_TO_AGENT) if (responder_id != @old_ticket.responder_id && responder)
    
    if status != @old_ticket.status
      return notify_by_email(EmailNotification::TICKET_RESOLVED) if (status == STATUS_KEYS_BY_TOKEN[:resolved])
      return notify_by_email(EmailNotification::TICKET_CLOSED) if (status == STATUS_KEYS_BY_TOKEN[:closed])
      #notify_by_email(EmailNotification::TICKET_REOPENED) if (status == STATUS_KEYS_BY_TOKEN[:open])
    end
  end
  
  def notify_by_email(notification_type)
    Helpdesk::TicketNotifier.send_later(:notify_by_email, notification_type, self)
  end
  
  def custom_fields
    @custom_fields = FlexifieldDef.all(:include => [:flexifield_def_entries =>:flexifield_picklist_val] , :conditions => ['account_id=? AND module=?',account_id,'Ticket']) 
  end
  
  def to_s
    "#{subject} (##{display_id})"
  end
  
  def reply_email
    email_config ? email_config.reply_email : account.default_email
  end

  #Some hackish things for virtual agent rules.
  def tag_names
    tags.collect { |tag| tag.name }
  end
  
  def from_email
    requester.email if requester
  end
  #virtual agent things end here..
  
  def pass_thro_biz_rules
     send_later(:delayed_rule_check )
  end
  
  def delayed_rule_check
      evaluate_on = check_rules     
      update_custom_field evaluate_on
      save!
   
 end
 
  
def check_rules
    load_flexifield 
    evaluate_on = self  
    account.va_rules.each do |vr|
      evaluate_on= vr.pass_through(self)
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
    unless self.custom_field.nil?          
      self.assign_ff_values self.custom_field    
    end
  end
  
  
  #To use liquid template...
  #Might be darn expensive db queries, need to revisit - shan.
  def to_liquid
    { 
      "id"                    => display_id,
      "subject"               => subject,
      "description"           => description,
      "requester"             => requester,
      "agent"                 => responder,
      "group"                 => group,
      "status"                => STATUS_NAMES_BY_KEY[status],
      "priority"              => PRIORITY_NAMES_BY_KEY[priority],
      "source"                => SOURCE_NAMES_BY_KEY[source],
      "ticket_type"           => TYPE_NAMES_BY_KEY[ticket_type],
      "tags"                  => tag_names.join(', '),
      "due_by_time"           => due_by.strftime("%B %e %Y at %I:%M %p"),
      "url"                   => helpdesk_ticket_url(self, :host => account.host),
      "latest_comment"        => liquidize_comment(latest_comment),
      "latest_public_comment" => liquidize_comment(latest_public_comment)
      }
  end
  
  def latest_comment #There must be a smarter way than this. maybe a proper named scope in Note?!
    notes.visible.newest_first.first
  end
  
  def latest_public_comment
    notes.visible.public.newest_first.first
  end
  
  def liquidize_comment(comm)
    "#{comm.user ? comm.user.name : 'System'} : #{comm.body}" if comm
  end
  #Liquid ends here

  #When the requester responds to this ticket, need to know whether to reopen?
  def active?
    !([STATUS_KEYS_BY_TOKEN[:resolved], STATUS_KEYS_BY_TOKEN[:closed]].include?(status))
  end
  
  def method_missing(method, *args, &block)
    super
  rescue NoMethodError => e

    logger.debug "method_missing :: args is #{args} and method:: #{method} and type is :: #{method.kind_of? String} "
    
    if (method.to_s.include? '=') && custom_field.has_key?(method.to_s.chomp("="))
      logger.debug "method_missing :: inside custom_field  args is #{args}  and method.chomp:: #{ method.to_s.chomp("=")}"
      
      ff_def_id = FlexifieldDef.find_by_account_id(self.account_id).id
      
      field = method.to_s.chomp("=")
      
      logger.debug "field is #{field}"
    
      self.ff_def = ff_def_id
   
      self.set_ff_value field , args
      
      save
      
      return
      
    end
    field =false
    unless custom_field.nil?
    field = custom_field.has_key?(method)    
    end
    raise e unless field
    custom_field[method]
  end
  
  def save_ticket_states
   
    ticket_state = Helpdesk::TicketState.new      
    self.ticket_states = ticket_state

  end
  
end
