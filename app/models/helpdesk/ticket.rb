require 'digest/md5'


class Helpdesk::Ticket < ActiveRecord::Base 
  include ActionController::UrlWriter
  include TicketConstants
  include Helpdesk::TicketModelExtension
  
  set_table_name "helpdesk_tickets"
  
  serialize :cc_email
  
  has_flexiblefields
  
  unhtml_it :description
  
  #by Shan temp
  attr_accessor :email, :name, :custom_field ,:customizer, :nscname, :twitter_id 
  
  before_validation :populate_requester, :set_default_values
  before_create :set_dueby, :save_ticket_states
  after_create :refresh_display_id, :save_custom_field, :pass_thro_biz_rules, :autoreply, 
      :create_initial_activity, :support_score_on_create
  before_update :cache_old_model, :update_dueby 
  after_update :save_custom_field, :update_ticket_states, :notify_on_update, :update_activity, 
      :support_score_on_update
  
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
  
  has_one :tweet,
    :as => :tweetable,
    :class_name => 'Social::Tweet',
    :dependent => :destroy
    
  has_one :ticket_states, :class_name =>'Helpdesk::TicketState', :dependent => :destroy
  has_one :ticket_topic,:dependent => :destroy
  has_one :topic, :through => :ticket_topic
  
  has_many :survey_handles, :as => :surveyable, :dependent => :destroy
  has_many :support_scores, :as => :scorable, :dependent => :destroy
  
  has_many :time_sheets , :class_name =>'Helpdesk::TimeSheet', :dependent => :destroy
  
  attr_protected :attachments #by Shan - need to check..
  
  accepts_nested_attributes_for :tweet
  
  named_scope :created_at_inside, lambda { |start, stop|
          { :conditions => [" helpdesk_tickets.created_at >= ? and helpdesk_tickets.created_at <= ?", start, stop] }
        }
  named_scope :resolved_and_closed_tickets, :conditions => {:status => [STATUS_KEYS_BY_TOKEN[:resolved],STATUS_KEYS_BY_TOKEN[:closed]]}
  
  named_scope :all_company_tickets,lambda { |customer| { 
        :joins => :requester,
        :conditions => [" users.customer_id = ?",customer]
  } 
  }
  
  named_scope :company_tickets_resolved_on_time,lambda { |customer| { 
        :joins => [:ticket_states,:requester],
        :conditions => ["helpdesk_tickets.due_by >  helpdesk_ticket_states.resolved_at AND users.customer_id = ?",customer]
  } 
  }

  named_scope :newest, lambda { |num| { :limit => num, :order => 'created_at DESC' } }
  named_scope :updated_in, lambda { |duration| { :conditions => [ 
    "helpdesk_tickets.updated_at > ?", duration ] } }
  
  named_scope :created_in, lambda { |duration| { :conditions => [ 
    "helpdesk_tickets.created_at > ?", duration ] } }
 
  named_scope :visible, :conditions => ["spam=? AND helpdesk_tickets.deleted=? AND status > 0", false, false] 
  named_scope :unresolved, :conditions => ["status in (#{STATUS_KEYS_BY_TOKEN[:open]}, #{STATUS_KEYS_BY_TOKEN[:pending]})"]
  named_scope :assigned_to, lambda { |agent| { :conditions => ["responder_id=?", agent.id] } }
  named_scope :requester_active, lambda { |user| { :conditions => 
    [ "requester_id=? and status in (#{STATUS_KEYS_BY_TOKEN[:open]}, #{STATUS_KEYS_BY_TOKEN[:pending]})",
      user.id ] } }
  named_scope :requester_completed, lambda { |user| { :conditions => 
    [ "requester_id=? and status in (#{STATUS_KEYS_BY_TOKEN[:resolved]}, #{STATUS_KEYS_BY_TOKEN[:closed]})",
      user.id ] } }
  
  #Sphinx configuration starts
  define_index do
    indexes :display_id, :sortable => true
    indexes :subject, :sortable => true
    indexes description
    indexes notes.body, :as => :note
    
    has account_id, deleted
    
    set_property :delta => :delayed
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
  validates_presence_of :requester_id
  validates_numericality_of :source, :status, :only_integer => true
  validates_numericality_of :requester_id, :responder_id, :only_integer => true, :allow_nil => true
  validates_inclusion_of :source, :in => 1..SOURCES.size
  validates_inclusion_of :status, :in => STATUS_KEYS_BY_TOKEN.values.min..STATUS_KEYS_BY_TOKEN.values.max
  #validates_format_of :email, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i, 
  #:allow_nil => false, :allow_blank => false

  def set_default_values
    self.status = TicketConstants::STATUS_KEYS_BY_TOKEN[:open] unless TicketConstants::STATUS_NAMES_BY_KEY.key?(self.status)
    self.source = TicketConstants::SOURCE_KEYS_BY_TOKEN[:portal] if self.source == 0
    self.ticket_type ||= account.ticket_type_values.first.value
    self.subject ||= ''
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
    self[:status] = STATUS_KEYS_BY_TOKEN[val] || val
  end

  def status_name
    STATUS_NAMES_BY_KEY[status]
  end
  
   def is_twitter?
    (tweet) and (!account.twitter_handles.blank?) 
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
    "[##{display_id}]"
  end
  
  def conversation(page = nil, no_of_records = 5)
    notes.visible.exclude_source('meta').newest_first.paginate(:page => page, :per_page => no_of_records)
  end

  def train(category)
    self[:trained] = true
    self[:spam] = (category == :spam)
  end
    
  def self.extract_id_token(text)
    pieces = text.match(/\[#([0-9]*)\]/) #by Shan changed to just numeric
    pieces && pieces[1]
  end

  #shihab-- date format may need to handle later. methode will set both due_by and first_resp
  def update_dueby
    set_dueby unless priority == @old_ticket.priority
  end
  
  def set_dueby 
    set_account_time_zone   
    createdTime = created_at || Time.zone.now
    self.priority = PRIORITY_KEYS_BY_TOKEN[:low] if priority.nil?
     
    sla_policy_id = requester.customer.sla_policy_id unless requester.customer.nil?
    sla_policy_id = Helpdesk::SlaPolicy.find_by_account_id_and_is_default(account_id, true) if sla_policy_id.nil?     
    sla_detail = Helpdesk::SlaDetail.find(:first, :conditions =>{:sla_policy_id =>sla_policy_id, :priority =>self.priority})
     
    if sla_detail.override_bhrs      
      self.due_by = createdTime + sla_detail.resolution_time.seconds      
      self.frDueBy = createdTime + sla_detail.response_time.seconds       
    else      
      self.due_by = get_business_time(sla_detail.resolution_time).div(60).business_minute.after(createdTime)      
      self.frDueBy =  get_business_time(sla_detail.response_time).div(60).business_minute.after(createdTime)     
    end 
     set_user_time_zone if User.current
     logger.debug "sla_detail_id :: #{sla_detail.id} :: due_by::#{self.due_by} and fr_due:: #{self.frDueBy} "   
  end
 
  def get_business_time time
    fact = time.div(86400) 
    (fact > 0) ? (business_time*fact) : time
  end

  def business_time
    logger.debug "business time is called"
    start_time = Time.parse(self.account.business_calendar.beginning_of_workday)
    end_time = Time.parse(self.account.business_calendar.end_of_workday)
    return (end_time - start_time)
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
  
  def populate_requester #by Shan temp  
    logger.debug "populate_requester :: email#{email} and twitter: #{twitter_id}"
    unless email.blank?
      if(requester_id.nil? or !email.eql?(requester.email))
        @requester = account.all_users.find_by_email(email)
        if @requester.nil?
          @requester = account.users.new          
          @requester.signup!({:user => {
            :email => self.email, 
            :name => (name || ''), 
            :user_role => User::USER_ROLES_KEYS_BY_TOKEN[:customer]}})
        end        
        self.requester = @requester  if @requester.valid?
      end
    else 
      
     unless twitter_id.blank?
       logger.debug "twitter_handle :: #{twitter_id.inspect} "
        if(requester_id.nil? or twitter_id.eql?(requester.twitter_id))
          @requester = account.all_users.find_by_twitter_id(twitter_id)
          if @requester.nil?
            @requester = account.users.new          
            @requester.signup!({:user => {:twitter_id =>twitter_id , :name => twitter_id ,
            :user_role => User::USER_ROLES_KEYS_BY_TOKEN[:customer],:active => true, :email => nil}})
          end        
          self.requester = @requester
        end
      end 
    end    
    
  end
  
  def autoreply     
    notify_by_email EmailNotification::NEW_TICKET #Do SPAM check.. by Shan
    notify_by_email(EmailNotification::TICKET_ASSIGNED_TO_GROUP) if group_id
    notify_by_email(EmailNotification::TICKET_ASSIGNED_TO_AGENT) if responder_id
    
    return notify_by_email(EmailNotification::TICKET_RESOLVED) if (status == STATUS_KEYS_BY_TOKEN[:resolved])
    return notify_by_email(EmailNotification::TICKET_CLOSED) if (status == STATUS_KEYS_BY_TOKEN[:closed])
  end

  def out_of_office?
    TicketConstants::OUT_OF_OFF_SUBJECTS.any? { |s| subject.downcase.include?(s) }
  end
  
  def included_in_cc?(from_email)
    (cc_email) and  (cc_email.any? {|email| email.include?(from_email) })
  end
  
  def cache_old_model
    @old_ticket = Helpdesk::Ticket.find id
  end
  
  def notify_on_update
    notify_by_email(EmailNotification::TICKET_ASSIGNED_TO_GROUP) if (group_id != @old_ticket.group_id && group)
    if (responder_id != @old_ticket.responder_id && responder && responder != User.current)
      notify_by_email(EmailNotification::TICKET_ASSIGNED_TO_AGENT)
    end
    
    if status != @old_ticket.status
      return notify_by_email(EmailNotification::TICKET_RESOLVED) if (status == STATUS_KEYS_BY_TOKEN[:resolved])
      return notify_by_email(EmailNotification::TICKET_CLOSED) if (status == STATUS_KEYS_BY_TOKEN[:closed])
      #notify_by_email(EmailNotification::TICKET_REOPENED) if (status == STATUS_KEYS_BY_TOKEN[:open])
    end
  end
  
  def save_ticket_states
    self.ticket_states = Helpdesk::TicketState.new
    ticket_states.assigned_at=Time.zone.now if responder_id
    ticket_states.first_assigned_at = Time.zone.now if responder_id
    ticket_states.pending_since=Time.zone.now if (status == STATUS_KEYS_BY_TOKEN[:pending])
    ticket_states.set_resolved_at_state if (status == STATUS_KEYS_BY_TOKEN[:resolved])
    ticket_states.resolved_at ||= ticket_states.set_closed_at_state if (status == STATUS_KEYS_BY_TOKEN[:closed])     
  end

  def update_ticket_states 
    
    ticket_states.assigned_at=Time.zone.now if (responder_id != @old_ticket.responder_id && responder)    
    if (@old_ticket.responder_id.nil? && responder_id != @old_ticket.responder_id && responder)
      ticket_states.first_assigned_at = Time.zone.now
    end
    
    if status != @old_ticket.status
      if (status == STATUS_KEYS_BY_TOKEN[:open])
        ticket_states.opened_at=Time.zone.now
        ticket_states.reset_tkt_states
      end
      
      ticket_states.pending_since=Time.zone.now if (status == STATUS_KEYS_BY_TOKEN[:pending])
      ticket_states.set_resolved_at_state if (status == STATUS_KEYS_BY_TOKEN[:resolved])
      
      if (status == STATUS_KEYS_BY_TOKEN[:closed]) 
        ticket_states.resolved_at ||= ticket_states.set_closed_at_state
      end
    end    
    ticket_states.save
  end
  
    
  def notify_by_email(notification_type)    
    Helpdesk::TicketNotifier.send_later(:notify_by_email, notification_type, self) if notify_enabled?(notification_type)
  end
  
  REQUESTER_NOTIFICATIONS = [ EmailNotification::NEW_TICKET, 
    EmailNotification::TICKET_CLOSED, EmailNotification::TICKET_RESOLVED  ]
  
  def notify_enabled?(notification_type)
    e_notification = account.email_notifications.find_by_notification_type(notification_type)
    
    REQUESTER_NOTIFICATIONS.include?(notification_type) ? e_notification.requester_notification? : 
      e_notification.agent_notification?
  end
  
  def custom_fields
    @custom_fields = FlexifieldDef.all(:include => 
      [:flexifield_def_entries =>:flexifield_picklist_vals], 
      :conditions => ['account_id=? AND module=?',account_id,'Ticket'] ) 
  end
  
  def to_s
    "#{subject} (##{display_id})"
  end
  
  def self.search_display(ticket)
    "#{ticket.excerpts.subject} (##{ticket.excerpts.display_id})"
  end
  
  def reply_email
    email_config ? email_config.friendly_email : account.default_email
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
     send_later(:delayed_rule_check )
  end
  
  def delayed_rule_check
    evaluate_on = check_rules     
    update_custom_field evaluate_on unless evaluate_on.nil?
    save! #Should move this to unless block.. by Shan
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
    unless self.custom_field.nil?          
      self.assign_ff_values self.custom_field    
    end
  end
  
  #To use liquid template...
  #Might be darn expensive db queries, need to revisit - shan.
  def to_liquid
    { 
      "id"                                => display_id,
      "encoded_id"                        => encode_display_id,
      "subject"                           => subject,
      "description"                       => description_with_attachments,
      "requester"                         => requester,
      "agent"                             => responder,
      "group"                             => group,
      "status"                            => STATUS_NAMES_BY_KEY[status],
      "priority"                          => PRIORITY_NAMES_BY_KEY[priority],
      "source"                            => SOURCE_NAMES_BY_KEY[source],
      "ticket_type"                       => ticket_type,
      "tags"                              => tag_names.join(', '),
      "due_by_time"                       => due_by.strftime("%B %e %Y at %I:%M %p"),
      "due_by_hrs"                        => due_by.strftime("%I:%M %p"),
      "fr_due_by_hrs"                     => frDueBy.strftime("%I:%M %p"),
      "url"                               => helpdesk_ticket_url(self, :host => account.host),
      "portal_url"                        => support_ticket_url(self, :host => portal_host),
      "portal_name"                       => portal_name,
      #"attachments"                      => liquidize_attachments(attachments),
      #"latest_comment"                   => liquidize_comment(latest_comment),
      "latest_public_comment"             => liquidize_comment(latest_public_comment)
      #"latest_comment_attachments"       => liquidize_c_attachments(latest_comment),
      #"latest_public_comment_attachments" => liquidize_c_attachments(latest_public_comment)
    }
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

  #When the requester responds to this ticket, need to know whether to reopen?
  def active?
    !([STATUS_KEYS_BY_TOKEN[:resolved], STATUS_KEYS_BY_TOKEN[:closed]].include?(status))
  end
  
  def open?
    (status == STATUS_KEYS_BY_TOKEN[:open])
  end
  
  def closed?
    (status == STATUS_KEYS_BY_TOKEN[:closed])
  end
  
  def resolved?
    (status == STATUS_KEYS_BY_TOKEN[:resolved])
  end
  
   def pending?
    (status == STATUS_KEYS_BY_TOKEN[:pending])
  end
  
  def method_missing(method, *args, &block)
    begin
      super
    rescue NoMethodError => e
      logger.debug "method_missing :: args is #{args} and method:: #{method} and type is :: #{method.kind_of? String} "
      load_flexifield if custom_field.nil?
      custom_field.symbolize_keys!
      
      if (method.to_s.include? '=') && custom_field.has_key?(method.to_s.chomp("=").to_sym)
        logger.debug "method_missing :: inside custom_field  args is #{args}  and method.chomp:: #{ method.to_s.chomp("=")}"
        
        ff_def_id = FlexifieldDef.find_by_account_id(self.account_id).id
        field = method.to_s.chomp("=")
        logger.debug "field is #{field}"
        self.ff_def = ff_def_id
        self.set_ff_value field, args
        save
        return
      end
      
      raise e unless custom_field.has_key?(method)
      custom_field[method]
    end
  end
  
  def to_xml(options = {})
      options[:indent] ||= 2
      xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
      xml.instruct! unless options[:skip_instruct]
      super(:builder => xml, :skip_instruct => true,:include => :notes) do |xml|
       xml.custom_field do
        self.ff_aliases.each do |label|    
          value = self.get_ff_value(label.to_sym()) 
          xml.tag!(label.gsub(/[^0-9A-Za-z_]/, ''), value) unless value.blank?
        end
       
      end
     end
  end
  
  def fetch_twitter_handle
    twt_handles = email_config.nil? ? account.primary_email_config.twitter_handles : email_config.twitter_handles
    twt_handles.first.id unless twt_handles.blank?
  end
  
  def portal_host
    (email_config && email_config.portal && !email_config.portal.portal_url.blank?) ? 
      email_config.portal.portal_url : account.host
  end
  
  def portal_name
    (email_config && email_config.portal) ? email_config.portal.name : account.portal_name
  end
  
  def update_activity
    self.changed.each do |attr|
      send(ACTIVITY_HASH[attr.to_sym()]) if ACTIVITY_HASH.has_key?(attr.to_sym())
    end
  end
  
   
   def group_name
      group.nil? ? "No Group" : group.name
    end
    
   def product_name
      email_config.nil? ? "No Product" : email_config.name
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
  
  private
  
    
    
    def create_source_activity
      create_activity(User.current, 'activities.tickets.source_change.long',
          {'source_name' => source_name}, 'activities.tickets.source_change.short')
    end
  
    def create_product_activity
      unless email_config
        create_activity(User.current, 'activities.tickets.product_change_none.long', {}, 
                                   'activities.tickets.product_change_none.short')
      else
        create_activity(User.current, 'activities.tickets.product_change.long',
          {'product_name' => email_config.name}, 'activities.tickets.product_change.short')
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
          {'status_name' => status_name}, 'activities.tickets.status_change.short')
    end
  
    def create_priority_activity
       create_activity(User.current, 'activities.tickets.priority_change.long', 
          {'priority_name' => priority_name}, 'activities.tickets.priority_change.short')
 
    end

    def create_deleted_activity
      create_activity(User.current, 'activities.tickets.deleted.long',
         {'ticket_id' => display_id}, 'activities.tickets.deleted.short')
    end
  
    def create_assigned_activity
      unless responder
        create_activity(User.current, 'activities.tickets.assigned_to_nobody.long', {}, 
                                   'activities.tickets.assigned_to_nobody.short')
      else
        create_activity(User.current, 
          @old_ticket.responder ? 'activities.tickets.reassigned.long' : 'activities.tickets.assigned.long', 
            {'eval_args' => {'responder_path' => ['responder_path', 
              {'id' => responder.id, 'name' => responder.name}]}}, 
            'activities.tickets.assigned.short')
      end
    end
    
    def support_score_on_create
      add_support_score unless active?
    end
    
    def support_score_on_update
      if active? && !@old_ticket.active?
        s_score = support_scores.find_by_score_trigger SupportScore::TICKET_CLOSURE
        s_score.destroy if s_score
      elsif !active? && @old_ticket.active?
        add_support_score
      end
    end
    
    def add_support_score
      SupportScore.add_support_score(self, ScoreboardRating.resolution_speed(self))
    end    
end
