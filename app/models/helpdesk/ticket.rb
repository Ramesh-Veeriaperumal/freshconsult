# encoding: utf-8
require 'digest/md5'

class Helpdesk::Ticket < ActiveRecord::Base
  
  include ActionController::UrlWriter
  include Helpdesk::TicketModelExtension
  include Helpdesk::Ticketfields::TicketStatus
  include ParserUtil
  include BusinessRulesObserver
  include Mobile::Actions::Ticket
  include Search::ElasticSearchIndex
  include Va::Observer::Util
  include Redis::RedisKeys
  include Redis::TicketsRedis
  include Redis::ReportsRedis
  include Redis::OthersRedis
  include Reports::TicketStats
  include Helpdesk::TicketActivities, Helpdesk::TicketElasticSearchMethods, Helpdesk::TicketCustomFields,
    Helpdesk::TicketNotifications

  SCHEMA_LESS_ATTRIBUTES = ["product_id","to_emails","product", "skip_notification",
                            "header_info", "st_survey_rating", "survey_rating_updated_at", "trashed", 
                            "access_token", "escalation_level", "sla_policy_id", "sla_policy", "manual_dueby"]
  OBSERVER_ATTR = []

  set_table_name "helpdesk_tickets"
  
  serialize :cc_email

  concerned_with :associations, :validations, :callbacks
  
  #by Shan temp
  attr_accessor :email, :name, :custom_field ,:customizer, :nscname, :twitter_id, :external_id, 
    :requester_name, :meta_data, :disable_observer

  attr_protected :attachments #by Shan - need to check..

  named_scope :created_at_inside, lambda { |start, stop|
          { :conditions => [" helpdesk_tickets.created_at >= ? and helpdesk_tickets.created_at <= ?", start, stop] }
        }
  named_scope :resolved_at_inside, lambda { |start, stop|
          { 
            :joins => [:ticket_states,:requester],
            :conditions => [%( helpdesk_ticket_states.resolved_at >= ? and 
              helpdesk_ticket_states.resolved_at <= ?), start, stop] }
        }

  named_scope :resolved_and_closed_tickets, :conditions => {:status => [RESOLVED,CLOSED]}
  
  named_scope :all_company_tickets,lambda { |customer| { 
        :joins => %(INNER JOIN users ON users.id = helpdesk_tickets.requester_id and 
          users.account_id = helpdesk_tickets.account_id ),
        :conditions => [" users.customer_id = ?",customer]
  } 
  }
  
  named_scope :company_tickets_resolved_on_time,lambda { |customer| { 
        :joins => %(INNER JOIN users ON users.id = helpdesk_tickets.requester_id and 
          users.account_id = helpdesk_tickets.account_id INNER JOIN helpdesk_ticket_states on 
          helpdesk_tickets.id = helpdesk_ticket_states.ticket_id and 
          helpdesk_tickets.account_id = helpdesk_ticket_states.account_id),
        :conditions => ["helpdesk_tickets.due_by >  helpdesk_ticket_states.resolved_at AND users.customer_id = ?",customer]
  } 
  }
  
   named_scope :resolved_on_time,
        :joins => %(INNER JOIN helpdesk_ticket_states on 
          helpdesk_tickets.id = helpdesk_ticket_states.ticket_id and 
          helpdesk_tickets.account_id = helpdesk_ticket_states.account_id),
        :conditions => ["helpdesk_tickets.due_by >  helpdesk_ticket_states.resolved_at"]
   
  named_scope :first_call_resolution,
           :joins  => %(INNER JOIN helpdesk_ticket_states on 
            helpdesk_tickets.id = helpdesk_ticket_states.ticket_id and 
            helpdesk_tickets.account_id = helpdesk_ticket_states.account_id),
           :conditions => ["(helpdesk_ticket_states.resolved_at is not null)  and  helpdesk_ticket_states.inbound_count = 1"]

  named_scope :company_first_call_resolution,lambda { |customer| { 
        :joins => %(INNER JOIN users ON users.id = helpdesk_tickets.requester_id and 
          users.account_id = helpdesk_tickets.account_id INNER JOIN helpdesk_ticket_states on 
          helpdesk_tickets.id = helpdesk_ticket_states.ticket_id and 
          helpdesk_tickets.account_id = helpdesk_ticket_states.account_id),
        :conditions => [%(helpdesk_ticket_states.resolved_at is not null  and  
          helpdesk_ticket_states.inbound_count = 1 AND users.customer_id = ?),customer]
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

  named_scope :spam_created_in, lambda { |user| { :conditions => [ 
    "helpdesk_tickets.created_at > ? and helpdesk_tickets.spam = true and requester_id = ?", user.deleted_at, user.id ] } }

  named_scope :with_display_id, lambda { |search_string| {  
    :include => [ :requester ],
    :conditions => ["helpdesk_tickets.display_id like ? and helpdesk_tickets.deleted is false","#{search_string}%" ],
    :order => 'helpdesk_tickets.display_id',
    :limit => 1000
    } 
  }

  named_scope :with_requester, lambda { |search_string| {  
    :joins => %(INNER JOIN users ON users.id = helpdesk_tickets.requester_id and 
      users.account_id = helpdesk_tickets.account_id and users.deleted = false),
    :conditions => ["users.name like ? and helpdesk_tickets.deleted is false","%#{search_string}%" ],
    :select => "helpdesk_tickets.*, users.name as requester_name",
    :order => "helpdesk_tickets.status, helpdesk_tickets.created_at DESC",
    :limit => 1000
    } 
  }

  class << self # Class Methods

    def agent_permission user
      permissions = {:all_tickets => [] , 
                   :group_tickets => ["group_id in (?) OR responder_id=?", 
                    user.agent_groups.collect{|ag| ag.group_id}.insert(0,0), user.id] , 
                   :assigned_tickets =>["responder_id=?", user.id] }
                  
      return permissions[Agent::PERMISSION_TOKENS_BY_KEY[user.agent.ticket_permission]]
    end

    def find_by_param(token, account)
      find_by_display_id_and_account_id(token, account.id)
    end

    def extract_id_token(text, delimeter)
      pieces = text.match(Regexp.new("\\[#{delimeter}([0-9]*)\\]")) #by Shan changed to just numeric
      pieces && pieces[1]
    end

    def search_display(ticket)
      "#{ticket.subject} (##{ticket.display_id})"
    end

  end
  
  def agent_permission_condition user
     permissions = {:all_tickets => "" , 
                   :group_tickets => " AND (group_id in (
                    #{user.agent_groups.collect{|ag| ag.group_id}.insert(0,0)}) OR responder_id= #{user.id}) " , 
                   :assigned_tickets => " AND (responder_id= #{user.id}) " }
                  
     return permissions[Agent::PERMISSION_TOKENS_BY_KEY[user.agent.ticket_permission]]
  end
  
  def get_default_filter_permissible_conditions user
    
     permissions = {:all_tickets => "" , 
                   :group_tickets => " [{\"condition\": \"responder_id\", \"operator\": \"is_in\", 
                   \"value\": \"#{user.id}\"}, {\"condition\": \"group_id\", \"operator\": \"is_in\", 
                   \"value\": \"#{user.agent_groups.collect{|ag| ag.group_id}.insert(0,0)}\"}] " , 
                   :assigned_tickets => "[{\"condition\": \"responder_id\", \"operator\": \"is_in\", 
                   \"value\": \"#{user.id}\"}]"}
                  
     return permissions[Agent::PERMISSION_TOKENS_BY_KEY[user.agent.ticket_permission]]
  end
  
  #Sphinx configuration starts
  define_index 'without_description' do
    
    indexes :display_id, :sortable => true
    indexes :subject, :sortable => true
    
    has account_id, deleted, responder_id, group_id, requester_id, status
    has sphinx_requester.customer_id, :as => :customer_id
    has SearchUtil::DEFAULT_SEARCH_VALUE, :as => :visibility, :type => :integer
    has SearchUtil::DEFAULT_SEARCH_VALUE, :as => :customer_ids, :type => :integer

    where "helpdesk_tickets.spam=0 and helpdesk_tickets.deleted = 0"

    #set_property :delta => Sphinx::TicketDelta

    set_property :field_weights => {
      :display_id   => 10,
      :subject      => 10
     }
  end

  define_index 'with_description' do
    
    indexes :display_id, :sortable => true
    indexes :subject, :sortable => true
    indexes description
    
    has account_id, deleted, responder_id, group_id, requester_id, status
    has sphinx_requester.customer_id, :as => :customer_id
    has SearchUtil::DEFAULT_SEARCH_VALUE, :as => :visibility, :type => :integer
    has SearchUtil::DEFAULT_SEARCH_VALUE, :as => :customer_ids, :type => :integer

    where "helpdesk_tickets.spam=0 and helpdesk_tickets.deleted = 0 and helpdesk_tickets.id > 5000000"

    #set_property :delta => Sphinx::TicketDelta

    set_property :field_weights => {
      :display_id   => 10,
      :subject      => 10,
      :description  => 5
     }
  end

  def description
    description
  end
 
  def description_html
    description_html
  end
 
  def description_with_ticket_body
    ticket_body ? ticket_body.description : read_attribute(:description)
  end
  alias_method_chain :description, :ticket_body


  def description_html_with_ticket_body
    ticket_body ? ticket_body.description_html : read_attribute(:description_html)
  end
  alias_method_chain :description_html, :ticket_body
  
  def to_param 
    display_id ? display_id.to_s : nil
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
    TicketConstants.translate_priority_name(priority)
  end
  
  def priority_key
    PRIORITY_TOKEN_BY_KEY[priority]
  end

  def populate_access_token #for generating access_token for old tickets
    set_token
    schema_less_ticket.update_access_token(self.access_token) # wrote a separate method for avoiding callback
  end

  def source=(val)
    self[:source] = SOURCE_KEYS_BY_TOKEN[val] || val
  end

  def source_name
    TicketConstants.translate_source_name(source)
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

  def conversation_since(since_id)
    return notes.visible.exclude_source('meta').newest_first.since(since_id)
  end

  def conversation_before(before_id)
    return notes.visible.exclude_source('meta').newest_first.before(before_id)
  end

  def conversation_count(page = nil, no_of_records = 5)
    notes.visible.exclude_source('meta').size
  end

  def time_tracked
    time_spent = 0
    time_sheets.each do |entry|
      time_spent += entry.running_time
    end
    time_spent
  end

  def train(category)
    self[:trained] = true
    self[:spam] = (category == :spam)
  end

  def set_time_zone
    return set_account_time_zone unless account.features?(:multiple_business_hours)
    if self.group.nil? || self.group.business_calendar.nil?
      set_account_time_zone
    else
      Time.zone = self.group.business_calendar.time_zone
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
  
  def company_id
    requester.customer_id if requester
  end

  #To use liquid template...
  #Might be darn expensive db queries, need to revisit - shan.
  def to_liquid
    @helpdek_ticket_drop ||= Helpdesk::TicketDrop.new self    
  end

  def url_protocol
    if self.product && !self.product.portal_url.blank?
      return self.product.portal.ssl_enabled? ? 'https' : 'http'
    else
      return account.ssl_enabled? ? 'https' : 'http'
    end
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
    return false if [:to_ary,:after_initialize_without_slave].include?(attribute.to_sym)
    # Array.flatten calls respond_to?(:to_ary) for each object.
    #  Rails calls array's flatten method on query result's array object. This was added to fix that.
    super(attribute) || SCHEMA_LESS_ATTRIBUTES.include?(attribute.to_s.chomp("=").chomp("?")) || 
      ticket_states.respond_to?(attribute) || custom_field_aliases.include?(attribute.to_s.chomp("=").chomp("?"))
  end

  def schema_less_attributes(attribute, args)
    RAILS_DEFAULT_LOGGER.debug "schema_less_attributes - method_missing :: args is #{args} and attribute :: #{attribute}"
    build_schema_less_ticket unless schema_less_ticket
    args = args.first if args && args.is_a?(Array) 
    (attribute.to_s.include? '=') ? schema_less_ticket.send(attribute, args) : schema_less_ticket.send(attribute)
  end

  def method_missing(method, *args, &block)
    begin
      super
    rescue NoMethodError => e
      RAILS_DEFAULT_LOGGER.debug "method_missing :: args is #{args.inspect} and method:: #{method} "
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
    options[:methods] = [:status_name, :requester_status_name, :priority_name, :source_name, :requester_name,:responder_name,:to_emails] unless options.has_key?(:methods)
    unless options[:basic].blank? # basic prop is made sure to be set to true from controllers always.
      options[:only] = [:display_id,:subject,:deleted]
      json_str = super options
      return json_str
    end
    if deep
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
    ticket_attributes = [:notes,:attachments]
    ticket_attributes = [] if options[:shallow]
    super(:builder => xml, :skip_instruct => true,:include => ticket_attributes, :except => [:account_id,:import_id], 
      :methods=>[:status_name, :requester_status_name, :priority_name, :source_name, :requester_name,:responder_name]) do |xml|
      xml.to_emails do
        self.to_emails.each do |emails|
          xml.tag!(:to_email,emails)
        end
      end
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
    if tweet
      tweet.twitter_handle_id 
    else            #default handle is set if twitter_handle_id is nil (for old tweets without twitter_handle_id)
      twt_handles = self.product ? self.product.twitter_handles : account.twitter_handles
      twt_handles.first.id unless twt_handles.blank?
    end
  end
  
  def portal_host
    (self.product && !self.product.portal_url.blank?) ? self.product.portal_url : account.host
  end
  
  def portal_name
    (self.product && self.product.portal_name) ? self.product.portal_name : account.portal_name
  end
  
  def support_path
    support_tickets_path(:host => portal_url)
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
    ticket_to_emails = (self.to_emails || []).collect {|e| e.tr('"','').strip}
    to_emails_array = (ticket_to_emails || []).clone

    reply_to_all_emails = (cc_emails_array + to_emails_array).uniq

    account.support_emails.each do |support_email|
      reply_to_all_emails.delete_if {|to_email| (
        (parse_email_text(support_email)[:email]).casecmp(parse_email_text(to_email.strip)[:email]) == 0)}
    end

    reply_to_all_emails
  end  

  def selected_reply_email
    account.pass_through_enabled? ? friendly_reply_email : account.default_friendly_email
  end

  def to_indexed_json
    to_json({
            :root => "helpdesk/ticket",
            :methods => [ :company_id, :es_from, :to_emails, :es_cc_emails, :es_fwd_emails],
            :only => [ :display_id, :subject, :description, :account_id, :responder_id, :group_id, :requester_id, :status, :spam, :deleted ], 
            :include => { :flexifield => { :only => es_flexifield_columns },
                          :attachments => { :only => [:content_file_name] }
                        }
            },
            false)
  end

  def unsubscribed_agents
    user_ids = subscriptions.map(&:user_id)
    account.agents_from_cache.reject{ |a| user_ids.include? a.user_id }
  end

  def resolved_now?
    @model_changes.key?(:status) && ((resolved? && @model_changes[:status][0] != CLOSED) || 
            (closed? && @model_changes[:status][0] != RESOLVED))
  end

  def reopened_now?
    @model_changes.key?(:status) && (active? && 
                      [RESOLVED, CLOSED].include?(@model_changes[:status][0]))
  end

  def ticket_changes
    @model_changes
  end

  # To keep flexifield & @custom_field in sync

  def custom_field
    @custom_field ||= retrieve_ff_values
  end

  def custom_field= custom_field_hash
    @custom_field = new_record? ? custom_field_hash : nil
    assign_ff_values custom_field_hash unless new_record?
  end

  def set_ff_value ff_alias, ff_value
    @custom_field = nil
    flexifield.set_ff_value ff_alias, ff_value
  end
  # flexifield - custom_field syncing code ends here

  private

    def sphinx_data_changed?
      description_html_changed? || requester_id_changed? || responder_id_changed? || group_id_changed? || deleted_changed?
    end

    def send_agent_assigned_notification?
      doer_id = Thread.current[:observer_doer_id]
      @model_changes.symbolize_keys[:responder_id] && responder && responder_id != doer_id && responder != User.current
    end
end
