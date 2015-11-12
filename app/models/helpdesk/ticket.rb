# encoding: utf-8
require 'digest/md5'

class Helpdesk::Ticket < ActiveRecord::Base

  self.primary_key = :id
  
  include Helpdesk::TicketModelExtension
  include Helpdesk::Ticketfields::TicketStatus
  include ParserUtil
  include BusinessRulesObserver
  include Mobile::Actions::Ticket
  include Search::ElasticSearchIndex
  include Va::Observer::Util
  include ApiWebhooks::Methods
  include Redis::RedisKeys
  include Redis::TicketsRedis
  include Redis::ReportsRedis
  include Redis::OthersRedis
  include Redis::DisplayIdRedis
  include Reports::TicketStats
  include Helpdesk::TicketsHelperMethods
  include ActionView::Helpers::TranslationHelper
  include Helpdesk::TicketActivities, Helpdesk::TicketElasticSearchMethods, Helpdesk::TicketCustomFields,
    Helpdesk::TicketNotifications
  include Helpdesk::Services::Ticket
  include BusinessHoursCalculation
  include AccountConstants

  SCHEMA_LESS_ATTRIBUTES = ["product_id","to_emails","product", "skip_notification",
                            "header_info", "st_survey_rating", "survey_rating_updated_at", "trashed", 
                            "access_token", "escalation_level", "sla_policy_id", "sla_policy", "manual_dueby", "sender_email", "parent_ticket",
                            "reports_hash"]
  OBSERVER_ATTR = []

  self.table_name =  "helpdesk_tickets"
  
  serialize :cc_email

  concerned_with :associations, :validations, :callbacks, :riak, :s3, :mysql, :attributes, :rabbitmq
  
  text_datastore_callbacks :class => "ticket"
  spam_watcher_callbacks :user_column => "requester_id"
  #by Shan temp
  attr_accessor :email, :name, :custom_field ,:customizer, :nscname, :twitter_id, :external_id, 
    :requester_name, :meta_data, :disable_observer, :highlight_subject, :highlight_description, :phone,
    :facebook_id, :send_and_set, :archive, :required_fields

#  attr_protected :attachments #by Shan - need to check..

  attr_protected :account_id, :display_id, :attachments #to avoid update of these properties via api.

  scope :created_at_inside, lambda { |start, stop|
          { :conditions => [" helpdesk_tickets.created_at >= ? and helpdesk_tickets.created_at <= ?", start, stop] }
        }
  scope :resolved_at_inside, lambda { |start, stop|
          { 
            :joins => [:ticket_states,:requester],
            :conditions => [%( helpdesk_ticket_states.resolved_at >= ? and 
              helpdesk_ticket_states.resolved_at <= ?), start, stop] }
        }

  scope :resolved_and_closed_tickets, :conditions => {:status => [RESOLVED,CLOSED]}
  scope :user_open_tickets, lambda { |user| 
    { :conditions => { :status => [OPEN], :requester_id => user.id } }
  }
  
  scope :all_company_tickets,lambda { |company_id| { 
        :joins => %(INNER JOIN users ON users.id = helpdesk_tickets.requester_id and 
          users.account_id = helpdesk_tickets.account_id ),
        :conditions => [" users.customer_id = ?",company_id]
  } 
  }
  
  scope :company_tickets_resolved_on_time,lambda { |company_id| { 
        :joins => %(INNER JOIN users ON users.id = helpdesk_tickets.requester_id and 
          users.account_id = helpdesk_tickets.account_id INNER JOIN helpdesk_ticket_states on 
          helpdesk_tickets.id = helpdesk_ticket_states.ticket_id and 
          helpdesk_tickets.account_id = helpdesk_ticket_states.account_id),
        :conditions => ["helpdesk_tickets.due_by >  helpdesk_ticket_states.resolved_at AND users.customer_id = ?",company_id]
  } 
  }
  
   scope :resolved_on_time,
        :joins => %(INNER JOIN helpdesk_ticket_states on 
          helpdesk_tickets.id = helpdesk_ticket_states.ticket_id and 
          helpdesk_tickets.account_id = helpdesk_ticket_states.account_id),
        :conditions => ["helpdesk_tickets.due_by >  helpdesk_ticket_states.resolved_at"]
   
  scope :first_call_resolution,
           :joins  => %(INNER JOIN helpdesk_ticket_states on 
            helpdesk_tickets.id = helpdesk_ticket_states.ticket_id and 
            helpdesk_tickets.account_id = helpdesk_ticket_states.account_id),
           :conditions => ["(helpdesk_ticket_states.resolved_at is not null)  and  helpdesk_ticket_states.inbound_count = 1"]

  scope :company_first_call_resolution,lambda { |company_id| { 
        :joins => %(INNER JOIN users ON users.id = helpdesk_tickets.requester_id and 
          users.account_id = helpdesk_tickets.account_id INNER JOIN helpdesk_ticket_states on 
          helpdesk_tickets.id = helpdesk_ticket_states.ticket_id and 
          helpdesk_tickets.account_id = helpdesk_ticket_states.account_id),
        :conditions => [%(helpdesk_ticket_states.resolved_at is not null  and  
          helpdesk_ticket_states.inbound_count = 1 AND users.customer_id = ?),company_id]
  } 
  }
        
  scope :newest, lambda { |num| { :limit => num, :order => 'created_at DESC' } }
  scope :updated_in, lambda { |duration| { :conditions => [ 
    "helpdesk_tickets.updated_at > ?", duration ] } }
  
  scope :created_in, lambda { |duration| { :conditions => [ 
    "helpdesk_tickets.created_at > ?", duration ] } }
 
  scope :visible, :conditions => ["spam=? AND helpdesk_tickets.deleted=? AND status > 0", false, false] 
  scope :unresolved, :conditions => ["helpdesk_tickets.status not in (#{RESOLVED}, #{CLOSED})"]
  scope :assigned_to, lambda { |agent| { :conditions => ["responder_id=?", agent.id] } }
  scope :requester_active, lambda { |user| { :conditions => 
    [ "requester_id=? ",
      user.id ], :order => 'created_at DESC' } }
  scope :requester_completed, lambda { |user| { :conditions => 
    [ "requester_id=? and status in (#{RESOLVED}, #{CLOSED})",
      user.id ] } }
      
  scope :permissible , lambda { |user| { :conditions => agent_permission(user)}  unless user.customer? }

  scope :assigned_tickets_permission , lambda { |user,ids| { 
    :select => "helpdesk_tickets.display_id",
    :conditions => ["responder_id=? and display_id in (?)", user.id, ids] } 
  }

  scope :group_tickets_permission , lambda { |user,ids| { 
    :select => "distinct helpdesk_tickets.display_id", 
    :joins => "LEFT JOIN agent_groups on helpdesk_tickets.group_id = agent_groups.group_id and helpdesk_tickets.account_id = agent_groups.account_id", 
    :conditions => ["(agent_groups.user_id=? or helpdesk_tickets.responder_id=? or helpdesk_tickets.requester_id=?) and display_id in (?)", user.id, user.id, user.id, ids] } 
  }
 
  scope :latest_tickets, lambda {|updated_at| {:conditions => ["helpdesk_tickets.updated_at > ?", updated_at]}}

  scope :with_tag_names, lambda { |tag_names| {
            :joins => :tags,
            :select => "helpdesk_tickets.id", 
            :conditions => ["helpdesk_tags.name in (?)",tag_names] } 
  }            

  
  scope :twitter_dm_tickets, lambda{ |twitter_handle_id| {
    :joins => "INNER JOIN social_tweets on helpdesk_tickets.id = social_tweets.tweetable_id and 
                  helpdesk_tickets.account_id = social_tweets.account_id",
              :conditions => ["social_tweets.tweetable_type = ? and social_tweets.tweet_type = ? and social_tweets.twitter_handle_id =?",
                      'Helpdesk::Ticket','dm', twitter_handle_id] } 
  }
              
  scope :spam_created_in, lambda { |user| { :conditions => [ 
    "helpdesk_tickets.created_at > ? and helpdesk_tickets.spam = true and requester_id = ?", user.deleted_at, user.id ] } }

  scope :with_requester, lambda { |search_string| {  
    :joins => %(INNER JOIN users ON users.id = helpdesk_tickets.requester_id and 
      users.account_id = helpdesk_tickets.account_id and users.deleted = false),
    :conditions => ["users.name like ? and helpdesk_tickets.deleted is false","%#{search_string}%" ],
    :select => "helpdesk_tickets.*, users.name as requester_name",
    :order => "helpdesk_tickets.status, helpdesk_tickets.created_at DESC",
    :limit => 1000
    } 
  }

  #META-READ-HACK!!
  # Check this while doing Meta Write Phase.
  # See if the Tickets can be fetched properly from Articles.
  # As of now Tickets are associated directly with Articles (not thru Meta)
  # It is better this way, but we'll have to make sure there are no new problems when we complete Multilingual feature.
  scope :article_tickets_by_user, lambda { |user| {
       :include => [:article, :requester, :ticket_status],
       :conditions => ["helpdesk_tickets.id = article_tickets.ticketable_id and solution_articles.user_id = ? and article_tickets.ticketable_type = ?", user.id, 'Helpdesk::Ticket']
     }
   }

  scope :all_article_tickets,
    :include => [:article, :requester, :ticket_status],
    :conditions => ["helpdesk_tickets.id = article_tickets.ticketable_id and article_tickets.ticketable_type = ?", 'Helpdesk::Ticket'],
    :order => "`helpdesk_tickets`.`created_at` DESC"

  scope :mobile_filtered_tickets , lambda{ |display_id, limit, order_param| {
    :conditions => ["display_id > (?)",display_id],
    :limit => limit,
    :order => order_param
    }
  }
  
  class << self # Class Methods

    def mobile_filtered_tickets(query_string,display_id,order_param,limit_val)
      if display_id != 0 
        where(query_string,display_id).order(order_param).limit(limit_val)
      else
        order(order_param).limit(limit_val)
      end
    end

    def agent_permission user
      case Agent::PERMISSION_TOKENS_BY_KEY[user.agent.ticket_permission]
      when :assigned_tickets
        ["`helpdesk_tickets`.responder_id=?", user.id]
      when :group_tickets
        ["`helpdesk_tickets`.group_id in (?) OR `helpdesk_tickets`.responder_id=? OR `helpdesk_tickets`.requester_id=?", 
                    user.agent_groups.collect{|ag| ag.group_id}.insert(0,0), user.id, user.id]
      when :all_tickets
        []
      end
    end

    def find_by_param(token, account)
      where(display_id: token, account_id: account.id).first
    end

    def find_all_by_param(token)
      find_all_by_display_id(token)
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
    (tweet) and (tweet.twitter_handle) 
  end
  alias :is_twitter :is_twitter?

  def is_facebook?
     (fb_post) and (fb_post.facebook_page) 
  end
  alias :is_facebook :is_facebook?
 
  def fb_replies_allowed?
    is_facebook? and !fb_post.reply_to_comment?
  end
 
  def is_fb_message?
   (fb_post) and (fb_post.facebook_page) and (fb_post.message?)
  end
  alias :is_fb_message :is_fb_message?

  def is_fb_wall_post?
    (fb_post) and (fb_post.facebook_page) and (fb_post.post?)
  end
  
  def is_fb_comment?
    (fb_post) and (fb_post.comment?)
  end
  
  def mobihelp?
    source == SOURCE_KEYS_BY_TOKEN[:mobihelp]
  end

  def outbound_email?
    (source == SOURCE_KEYS_BY_TOKEN[:outbound_email]) && Account.current.compose_email_enabled?  
  end

  #This method will return the user who initiated the outbound email
  #If it doesn't exist, returning requester.
  def outbound_initiator
    return requester unless outbound_email? 
    begin
      meta_note = self.notes.find_by_source(Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["meta"]) 
      meta = YAML::load(meta_note.body) unless meta_note.blank?
      if !meta.blank? && meta["created_by"].present?
        user_id = meta["created_by"] 
        user = account.all_users.find_by_id(user_id) if user_id #searching all_users to handle if the initiator is deleted later.
        user.present? ? user : requester
      else
        requester
      end
    rescue ArgumentError => e
      Rails.logger.info ":::Outbound Email Exception - #{e.message}"
      requester
    end
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

  def get_access_token #for generating access_token for old tickets
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

  def chat?
    source == SOURCE_KEYS_BY_TOKEN[:chat]
  end
  
  def requester_info
    requester.get_info if requester
  end

  def requester_phone
    (requester_has_phone?)? requester.phone : requester.mobile if requester
  end

  def not_editable?
    requester and !requester_has_email? and !requester_has_phone?
  end
  
  def requester_has_email?
    (requester) and (requester.email.present?)
  end

  def requester_has_phone?
    requester and requester.phone.present?
  end

  def encode_display_id
    "[#{ticket_id_delimiter}#{display_id}]"
  end

  def conversation(page = nil, no_of_records = 5, includes=[])
    notes.visible.exclude_source('meta').newest_first.paginate(:page => page, :per_page => no_of_records, :include => includes)
  end

  def conversation_since(since_id)
    return notes.visible.exclude_source('meta').since(since_id)
  end

  def conversation_before(before_id)
    includes = [:survey_remark, :user, :attachments, :schema_less_note, :cloud_files, :note_old_body]
    notes.visible.exclude_source('meta').newest_first.before(before_id).includes(includes)
  end

  def conversation_count(page = nil, no_of_records = 5)
    notes.visible.exclude_source('meta').size
  end
  
  def latest_twitter_comment_user
    latest_tweet = notes.latest_twitter_comment.first
    reply_to_user = latest_tweet.nil? ? requester.twitter_id : latest_tweet.user.twitter_id
    "@#{reply_to_user}"
  end

  def round_off_time_hrs seconds
    hh = (seconds/3600).to_i
    mm = ((seconds % 3600)/60.to_f).round

    hh.to_s.rjust(2,'0') + ":" + mm.to_s.rjust(2,'0')
  end

  def time_tracked
    time_sheets.sum(&:running_time)
  end

  def billable_hours
    round_off_time_hrs(time_sheets.hour_billable(true).sum(&:running_time))
  end

  def time_tracked_hours
    round_off_time_hrs(time_tracked)
  end

  def first_res_time_bhrs
    hhmm(self.first_resp_time_by_bhrs)
  end

  def resolution_time_bhrs
    hhmm(self.resolution_time_by_bhrs)
  end

  def hhmm(seconds)
    seconds = 0 if seconds.nil?
    hh = (seconds/3600).to_i
    mm = ((seconds % 3600) / 60).to_i
    ss = (seconds % 60).to_i
    "#{hh.to_s.rjust(2,'0')}:#{mm.to_s.rjust(2,'0')}:#{ss.to_s.rjust(2,'0')}"
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
    (cc_email_hash) and  (cc_email_hash[:fwd_emails].any? {|email| email.downcase.include?(from_email.downcase) }) 
  end
  
  def included_in_cc?(from_email)
    (cc_email_hash) and  ((cc_email_hash[:cc_emails].any? {|email| email.include?(from_email.downcase) }) or 
                     (cc_email_hash[:fwd_emails].any? {|email| email.include?(from_email.downcase) }) or
                     included_in_to_emails?(from_email))
  end

  def included_in_to_emails?(from_email)
    (self.to_emails || []).select{|email_id| email_id.downcase.include?(from_email.downcase) }.present?
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
  
  def reply_email_config
    email_config ? email_config : account.primary_email_config
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

  def ticket_tags
    tag_names.join(',')
  end

  def ticket_survey_results
     recent_survey = survey_results.last(:order => "id")
     recent_survey.text if recent_survey
  end
  
  def subject_or_description
    [subject, description]
  end
  
  def from_email
    (account.features_included?(:contact_merge_ui) and self.sender_email.present?) ? self.sender_email : requester.email
  end

  def ticlet_cc
    cc_email.nil? ? [] : cc_email[:cc_emails]
  end
  
  def contact_name
    requester.name if requester
  end
  
  def company_name
    requester.company.name if (requester && requester.company)
  end
  
  def company_id
    requester.company_id if requester
  end

  def last_interaction
    notes.visible.newest_first.exclude_source("feedback").exclude_source("meta").exclude_source("forward_email").first.try(:body).to_s
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
  
  def description_html=(value)
    warn "[DEPRECATION] This method will be removed soon, please use ticket_body.description_html."
    write_attribute(:description_html,value)
  end
  
  def description_with_attachments
    attachments.empty? ? description_html : 
        "#{description_html}\n\nTicket attachments :\n#{liquidize_attachments(attachments)}\n"
  end
  
  def liquidize_attachments(attachments)
    attachments.each_with_index.map { |a, i| 
      "#{i+1}. <a href='#{Rails.application.routes.url_helpers.helpdesk_attachment_url(a, :host => portal_host)}'>#{a.content_file_name}</a>"
      }.join("<br />") #Not a smart way for sure, but donno how to do this in RedCloth?
  end
  
  def latest_public_comment
    notes.visible.public.newest_first.first
  end

  def latest_private_comment
    notes.visible.private.newest_first.first
  end
  
  def liquidize_comment(comm)
    if comm
      c_descr = "#{comm.user ? comm.user.name : 'System'} : #{comm.body_html}"
      all_attachments = comm.all_attachments
      unless all_attachments.empty?
        c_descr = "#{c_descr}\n\nAttachments :\n#{liquidize_attachments(all_attachments)}\n"
      end
      c_descr
    end
  end
  #Liquid ends here
  
  def respond_to?(attribute, include_private=false)
    return false if [:empty?, :to_ary,:after_initialize_without_slave].include?(attribute.to_sym) || (attribute.to_s.include?("__initialize__") || attribute.to_s.include?("__callbacks"))
    # Array.flatten calls respond_to?(:to_ary) for each object.
    #  Rails calls array's flatten method on query result's array object. This was added to fix that.
    
    # Should include methods like to_a, created_on, updated_on as record_time_stamps is calling these mthds before any write operation
    # .blank? will call respond_to?(:empty)
    return super(attribute, include_private) if [:to_a, :created_on, :updated_on, :empty?].include?(attribute)
    super(attribute, include_private) || SCHEMA_LESS_ATTRIBUTES.include?(attribute.to_s.chomp("=").chomp("?")) || 
      ticket_states.respond_to?(attribute) || custom_field_aliases.include?(attribute.to_s.chomp("=").chomp("?"))
  end

  def schema_less_attributes(attribute, args)
    Rails.logger.debug "schema_less_attributes - method_missing :: args is #{args} and attribute :: #{attribute}"
    build_schema_less_ticket unless schema_less_ticket
    args = args.first if args && args.is_a?(Array) 
    (attribute.to_s.include? '=') ? schema_less_ticket.send(attribute, args) : schema_less_ticket.send(attribute)
  end

  def method_missing(method, *args, &block)
    begin
      super
    rescue NoMethodError, NameError => e
      Rails.logger.debug "method_missing :: args is #{args.inspect} and method:: #{method} "
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

  def as_json(options = {}, deep=true)#TODO-RAILS3
    return super(options) unless options[:tailored_json].blank?
    options[:methods] = [:status_name, :requester_status_name, :priority_name, :source_name, :requester_name,:responder_name,:to_emails, :product_id] unless options.has_key?(:methods)
    unless options[:basic].blank? # basic prop is made sure to be set to true from controllers always.
      options[:only] = [:display_id,:subject,:deleted]
      json_hsh = super options
      return json_hsh
    end
    if deep
      self[:notes] = self.notes
      options[:methods].push(:attachments)
      options[:include] = options[:include] || {}
      options[:include][:tags] = {:only => [:name]} if options[:include].is_a? Hash
    end
    options[:except] = [:account_id,:import_id]
    options[:methods].push(:custom_field)
    json_hash = super options.merge(:root => 'helpdesk_ticket')
    json_hash
  end


  def to_xml(options = {})
    options[:indent] ||= 2
    xml = options[:builder] ||= ::Builder::XmlMarkup.new(:indent => options[:indent])
    xml.instruct! unless options[:skip_instruct]

    unless options[:basic].blank? #to give only the basic properties[basic prop set from 
      return super(:builder =>xml,:skip_instruct => true,:only =>[:display_id,:subject,:deleted],
          :methods=>[:status_name, :requester_status_name, :priority_name, :source_name, :requester_name,:responder_name])
    end
    ticket_attributes = [:notes,:attachments]
    ticket_attributes = {:notes => {},:attachments => {},:tags=> {:only => [:name]}}
    ticket_attributes = [] if options[:shallow]
    super(:builder => xml, :root => "helpdesk-ticket", :skip_instruct => true,:include => ticket_attributes, :except => [:account_id,:import_id], 
      :methods=>[:status_name, :requester_status_name, :priority_name, :source_name, :requester_name,:responder_name, :product_id]) do |xml|
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

  def portal
    (self.product && self.product.portal) || account.main_portal
  end
  
  def portal_host
    (self.product && !self.product.portal_url.blank?) ? self.product.portal_url : account.host
  end

  def solution_article_host article
    (self.product && !self.product.portal_url.blank? && (self.product.portal.has_solution_category?(article.folder.category_id))) ? self.product.portal_url : account.host
  end
  
  def portal_name
    (self.product && self.product.portal_name) ? self.product.portal_name : account.portal_name
  end
  
  def support_path
    Rails.application.routes.url_helpers.support_tickets_path(:host => portal_url)
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
    
  def company_name
    requester.company.nil? ? "No company" : requester.company.name
  end
    
  def cc_email_hash
    if cc_email.is_a?(Array)     
      {:cc_emails => cc_email, :fwd_emails => [], :reply_cc => cc_email}
    else
      cc_email
    end
  end

  def current_cc_emails
    return [] unless cc_email
    unless cc_email.is_a?(Array)
      (cc_email[:reply_cc] || cc_email[:cc_emails] || [])
    else
      cc_email
    end
  end

  def reply_to_all_emails
    emails_hash = cc_email_hash
    return [] if emails_hash.nil?
    to_emails_array = []
    cc_emails_array = emails_hash[:cc_emails].blank? ? [] : emails_hash[:cc_emails]
    ticket_to_emails = self.to_emails || []
    to_emails_array = (ticket_to_emails || []).clone

    reply_to_all_emails = (cc_emails_array + to_emails_array).compact.uniq

    account.support_emails.each do |support_email|
      reply_to_all_emails.delete_if {|to_email| (
        (trim_trailing_characters(parse_email_text(support_email)[:email])).casecmp(trim_trailing_characters(parse_email_text(to_email.strip)[:email])) == 0) ||
        (parse_email_with_domain(to_email.strip)[:domain] == account.full_domain)
      }
    end

    reply_to_all_emails
  end  

  def selected_reply_email
    account.pass_through_enabled? ? friendly_reply_email : account.default_friendly_email
  end

  def to_indexed_json
    as_json({
            :root => "helpdesk/ticket",
            :tailored_json => true,
            :methods => [ :company_id, :es_from, :to_emails, :es_cc_emails, :es_fwd_emails],
            :only => [ :display_id, :subject, :description, :account_id, :responder_id,
                       :group_id, :requester_id, :status, :spam, :deleted, :source, :priority, :due_by,
                       :created_at, :updated_at ],
            :include => { :flexifield => { :only => es_flexifield_columns },
                          :attachments => { :only => [:content_file_name] },
                          :ticket_states => { :only => [ :resolved_at, :closed_at, :agent_responded_at,
                                                         :requester_responded_at, :status_updated_at ] }
                        }
            },
            false).to_json
  end

  #To-do: Need to verify with mappings
  def to_es_json
    as_json({
      :root => false,
      :tailored_json => true,
      :methods => [
                    :company_id, :tag_names, :tag_ids, :watchers, :status_stop_sla_timer, 
                    :status_deleted, :product_id, :trashed
                  ],
      :only => [
                  :requester_id, :responder_id, :status, :source, :spam, :deleted, 
                  :created_at, :updated_at, :account_id, :display_id, :group_id, :due_by, 
                  :frDueBy, :priority, :ticket_type
                ]
    }, false).merge(custom_attributes).to_json
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

  #Ecommerce methods
  def ecommerce?
    source == SOURCE_KEYS_BY_TOKEN[:ecommerce] && self.ebay_question.present?
  end

  def allow_ecommerce_reply?
    (self.ecommerce? && self.ebay_account && self.ebay_account.active?)
  end

  #Ecommerce method code ends

  # To keep flexifield & @custom_field in sync

  def custom_field
    # throws error in retrieve_ff_values if flexifield is nil and custom_field is not set. Hence the check
    return nil unless @custom_field || flexifield
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

  def custom_field_type_mappings
    @custom_field_mapping ||= begin 
      self.account.ticket_fields.custom_fields.inject({}) { |a, f| 
        a[f.name] = f.field_type
        a
      }
    end
  end

  def resolution_status
    return "" unless [RESOLVED, CLOSED].include?(status)
    resolved_at.nil? ? "" : ((resolved_at < due_by)  ? t('export_data.in_sla') : t('export_data.out_of_sla'))
  end

  def first_response_status
    #Hack: for outbound emails, first response status needs to be blank. 
    (outbound_email? or first_response_time.nil?) ? "" : ((first_response_time < frDueBy) ? t('export_data.in_sla') : t('export_data.out_of_sla'))
  end

  def requester_fb_profile_id
    requester.fb_profile_id
  end
  

  def can_send_survey?(s_while)
     survey = account.survey
     (!survey.nil? && survey.can_send?(self,s_while))
  end

  # Instance level spam watcher condition
  # def rl_enabled?
  #   self.account.features?(:resource_rate_limit)) && !self.instance_variable_get(:@skip_resource_rate_limit) && self.import_id.blank?
  # end

  def show_reply?
    (self.is_twitter? or self.fb_replies_allowed? or self.from_email.present? or self.mobihelp? or self.allow_ecommerce_reply?)
  end

  def search_fields_updated?
    attribute_fields = ["subject", "description", "responder_id", "group_id", "requester_id",
                       "status", "spam", "deleted", "source", "priority", "due_by", "to_emails", "cc_email"]
    include_fields = es_flexifield_columns
    all_fields = attribute_fields | include_fields
    (@model_changes.keys.map(&:to_s) & all_fields).any?
  end

  def to_mobihelp_json
    json_data = as_json({
            :root => "helpdesk_ticket",
            :tailored_json => true,
            :only => [ :display_id, :subject, :description, :status, :id, :deleted, :source, :created_at,
              :updated_at ],
            :include => { :mobihelp_notes => { :except => :account_id } }
      },
      false)
    hash_data = ActiveSupport::JSON.decode(json_data.to_json)
    notes = []
    hash_data["helpdesk_ticket"]["mobihelp_notes"].each do |n|
      notes << { :note => n }
    end
    hash_data["helpdesk_ticket"]["notes"] = notes
    hash_data["helpdesk_ticket"].delete "mobihelp_notes"
    hash_data.to_json()
  end

  def header_info_present?
    header_info.present? && header_info[:message_ids].present?
  end

  def linked_to_integration?(installed_app)
    self.linked_applications.where(:id => installed_app.id).any?
  end

  # Used by API v2
  def self.filter_conditions(ticket_filter = nil, current_user = nil)
    {
      default: {
        conditions: { spam: false }
      },
      spam: {
        conditions: { spam: true }
      },
      deleted: {
        conditions: { deleted: true, helpdesk_schema_less_tickets: { boolean_tc02: false } },
        joins: :schema_less_ticket
      },
      new_and_my_open: {
        conditions: { status: OPEN,  responder_id: [nil, current_user.try(:id)], spam: false }
      },
      watching: {
          :conditions => {helpdesk_subscriptions: {user_id: current_user.id}, spam: false},
          :joins => :subscriptions
      },
      requester_id: {
        conditions: { requester_id: ticket_filter.try(:requester_id), spam: false }
      },
      company_id: { 
        conditions: { users: { customer_id: ticket_filter.try(:company_id) }, spam: false },
        joins: :requester
      },
      updated_since: {
        conditions: ['helpdesk_tickets.updated_at >= ? AND helpdesk_tickets.spam = false', ticket_filter.try(:updated_since).try(:to_time).try(:utc)]
      }
    }
  end

  private
    def sphinx_data_changed?
      description_html_changed? || requester_id_changed? || responder_id_changed? || group_id_changed? || deleted_changed?
    end

    def send_agent_assigned_notification?
      doer_id = Thread.current[:observer_doer_id]
      @model_changes[:responder_id] && responder && responder_id != doer_id && responder != User.current
    end

    # def rl_exceeded_operation
    #   key = "RL_%{table_name}:%{account_id}:%{user_id}" % {:table_name => self.class.table_name, :account_id => self.account_id,
    #                                                          :user_id => self.requester_id }
    #   $spam_watcher.rpush(ResourceRateLimit::NOTIFY_KEYS, key)
    # end

end
