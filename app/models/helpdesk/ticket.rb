require 'digest/md5'

class Helpdesk::Ticket < ActiveRecord::Base 
  include ActionController::UrlWriter
  include TicketConstants
  
  set_table_name "helpdesk_tickets"
  
  has_flexiblefields
  
  #by Shan temp
  attr_accessor :email, :custom_field
  after_create :refresh_display_id, :autoreply, :pass_thro_biz_rules
  before_create :populate_requester

  before_validation_on_create :set_tokens
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
    
  has_one :customizer, :class_name =>'Helpdesk::FormCustomizer'
  
  
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
  validates_uniqueness_of :id_token
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

  def create_activity(user, description, activity_data = {})
    activities.create(
      :description => description,
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

  def set_tokens
    self.id_token ||= make_token(Helpdesk::SECRET_1)
    self.access_token ||= make_token(Helpdesk::SECRET_2)
  end
  
  #shihab-- date format may need to handle later. methode will set both due_by and first_resp
   def set_dueby     
   
    createdTime = Time.now    
       
     unless self.created_at.nil?
       
       createdTime = self.created_at
       
     end
     
     self.priority = 1 if priority.nil?
     
     
     sla_policy_id = nil
     
     unless self.requester.customer.nil?
     
     sla_policy_id = self.requester.customer.sla_policy_id
     
     end
     
    
     sla_policy_id = Helpdesk::SlaPolicy.find_by_account_id_and_is_default(account_id, true).id if sla_policy_id.nil?
     
        
 
     self.due_by = createdTime + Helpdesk::SlaDetail.find(:first , :conditions =>{:sla_policy_id =>sla_policy_id, :priority =>self.priority}).resolution_time.seconds
     self.frDueBy = createdTime + Helpdesk::SlaDetail.find(:first , :conditions =>{:sla_policy_id =>sla_policy_id, :priority =>self.priority}).response_time.seconds
       
    
     
  end

  def make_token(secret)
    Digest::MD5.hexdigest(secret + Time.now.to_f.to_s).downcase
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
        @requester.signup!({:user => {:email => self.email, :name => '', :role_token => 'customer'}})
      end
      
      self.requester = @requester
    end
  end
  
  def autoreply
    notify_by_email EmailNotification::NEW_TICKET
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
    send_later(:delayed_rule_check)
  end
  
  def delayed_rule_check
    if check_rules
      update_custom_field
      save!
    end
  end
  
  def check_rules
    account.va_rules.each do |vr|
      return true if vr.pass_through(self)
    end
  end
  
  def update_custom_field
    flexi_field = self.custom_field  
    
    self.custom_field.each do |key,value|    
      flexi_field[key] = self.read_attribute(key)      
    end
  
    ff_def_id = FlexifieldDef.find_by_account_id(self.account_id).id    
    self.ff_def = ff_def_id  
     
    unless flexi_field.nil?     
      self.assign_ff_values flexi_field    
    end
  end
  
  
  #To use liquid template...
  def to_liquid
    { "display_id"  => display_id,
      "subject"     => subject,
      "description" => description,
      "requester"   => requester,
      "owner"       => responder,
      "group"       => group,
      "url"         => helpdesk_ticket_url(self, :host => account.full_domain) }
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
    
    field = custom_field.has_key?(method)    
    raise e unless field
    custom_field[method]
  end
  
end
