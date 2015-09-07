# encoding: utf-8
require 'digest/md5'

class Helpdesk::ArchiveTicket < ActiveRecord::Base
  include TicketConstants
  include Helpdesk::TicketCustomFields
  include Search::ElasticSearchIndex
  include ArchiveTicketExportParams
  
  self.primary_key = :id
  belongs_to_account
  belongs_to :requester, :class_name => 'User'
  belongs_to :responder, :class_name => 'User', :conditions => 'users.helpdesk_agent = true'
  belongs_to :group
  
  has_one :archive_ticket_association, 
        :class_name => "Helpdesk::ArchiveTicketAssociation",
        :dependent => :destroy
  has_many :archive_notes,
           :class_name => "Helpdesk::ArchiveNote",
           :dependent => :destroy

  has_many :inline_attachments, :class_name => "Helpdesk::Attachment", 
                                :conditions => { :attachable_type => "ArchiveTicket::Inline" },
                                :foreign_key => "attachable_id",
                                :dependent => :destroy
                                
  has_many :activities, :class_name => 'Helpdesk::Activity',:as => :notable, :dependent => :destroy
  has_many :survey_handles, :as => :surveyable, :dependent => :destroy
  has_many :survey_results, :as => :surveyable, :dependent => :destroy
  has_many :custom_survey_handles, :class_name => 'CustomSurvey::SurveyHandle', :as => :surveyable, :dependent => :destroy
  has_many :custom_survey_results, :class_name => 'CustomSurvey::SurveyResult', :as => :surveyable, :dependent => :destroy
  has_many :support_scores, :as => :scorable, :dependent => :destroy
  has_many :time_sheets, :class_name => 'Helpdesk::TimeSheet',:as => 'workable',:dependent => :destroy, :order => "executed_at"
  has_one :tweet, :as => :tweetable, :class_name => 'Social::Tweet', :dependent => :destroy
  has_one :fb_post, :as => :postable, :class_name => 'Social::FbPost',  :dependent => :destroy
  has_one :freshfone_call, :class_name => 'Freshfone::Call', :as => 'notable', :dependent => :destroy
  has_one :archive_child, :class_name => 'Helpdesk::ArchiveChild', :dependent => :destroy
  has_one :ticket, :through => :archive_child

  has_many :tag_uses, :as => :taggable, :class_name => 'Helpdesk::TagUse', :dependent => :destroy
  has_many :tags, :class_name => 'Helpdesk::Tag', :through => :tag_uses
  has_many :integrated_resources, :as => :local_integratable, :class_name => 'Integrations::IntegratedResource', :dependent => :destroy

  has_one :ticket_topic, :as => :ticketable, :dependent => :destroy
  has_one :topic, :through => :ticket_topic
  
  belongs_to :ticket_status, :class_name =>'Helpdesk::TicketStatus', :foreign_key => "status", :primary_key => "status_id"
  belongs_to :product
  
  has_many :public_notes,
    :class_name => 'Helpdesk::ArchiveNote',
    :conditions => { :private =>  false }
  
  has_flexiblefields :class_name => 'Flexifield', :as => :flexifield_set
  has_many_attachments
  has_many_cloud_files
  
  delegate :active?, :open?, :is_closed, :closed?, :resolved?, :pending?, :onhold?, 
    :onhold_and_closed?, :to => :ticket_status, :allow_nil => true

  attr_protected :account_id
  attr_accessor :highlight_subject, :highlight_description, :archive_ticket_state
  accepts_nested_attributes_for :archive_ticket_association, allow_destroy: true

  concerned_with :rabbitmq

  SORT_FIELDS = [
    [ :created_at , "tickets_filter.sort_fields.date_created"  ],
    [ :updated_at , "tickets_filter.sort_fields.last_modified" ],
    [ :priority   , "tickets_filter.sort_fields.priority"      ]
  ]
  SCHEMA_LESS_FIELDS = {
    :sla_policy_id => "long_tc01",
    :merge_ticket => "long_tc02",
    :reports_hash => "text_tc02",
    :sender_email => "string_tc03"
  }
  NON_TEXT_FIELDS = ["custom_text", "custom_paragraph"]

  
  scope :permissible , lambda { |user| { :conditions => agent_permission(user)} unless user.customer? }
  scope :requester_active, lambda { |user| { :conditions => [ "requester_id=? ", 
    user.id ], :order => 'created_at DESC' } }
  scope :newest, lambda { |num| { :limit => num, :order => 'created_at DESC' } }
  scope :all_company_tickets,lambda { |company_id| { 
        :joins => %(INNER JOIN users ON users.id = archive_tickets.requester_id and 
          users.account_id = archive_tickets.account_id ),
        :conditions => [" users.customer_id = ?",company_id]
    } 
  }
  scope :created_at_inside, lambda { |start, stop| { :conditions => 
    [" archive_tickets.created_at >= ? and archive_tickets.created_at <= ?", start, stop] }
  }
  # do we need this
  validates_uniqueness_of :display_id, :scope => :account_id
  default_scope where(:progress => false)

  def self.agent_permission user
    permissions = {
      :all_tickets => [] , 
      :group_tickets => ["group_id in (?) OR responder_id = ? OR requester_id = ?", 
                  user.agent_groups.collect{|ag| ag.group_id}.insert(0,0), user.id, user.id], 
      :assigned_tickets =>["responder_id = ?", user.id]
    }
                 
    permissions[Agent::PERMISSION_TOKENS_BY_KEY[user.agent.ticket_permission]]
  end

  def self.sort_fields_options
    SORT_FIELDS.map { |i| [I18n.t(i[1]), i[0]] }
  end

  def self.load_by_param(token, account)
    find_by_display_id_and_account_id(token, account.id)
  end

  def source_name
    TicketConstants.translate_source_name(source)
  end

  def priority_name
    TicketConstants.translate_priority_name(priority)
  end
  
  def priority_key
    PRIORITY_TOKEN_BY_KEY[priority]
  end

  def status_name
    Helpdesk::TicketStatus.translate_status_name(ticket_status)
  end

  def freshness
    responder ? :reply : :new
  end

  def is_twitter?
    (tweet) and (tweet.twitter_handle) 
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
  
  def is_fb_comment?
    (fb_post) and (fb_post.comment?)
  end
  
  def mobihelp?
    source == SOURCE_KEYS_BY_TOKEN[:mobihelp]
  end

  def chat?
    source == SOURCE_KEYS_BY_TOKEN[:chat]
  end

  def description
    archive_ticket_association.description
  end

  def description_html
    archive_ticket_association.description_html
  end

  def conversation(page = nil, no_of_records = 5, includes=[])
    archive_notes.exclude_source('meta').newest_first(:include => includes).paginate(:page => page, :per_page => no_of_records)
  end

  def conversation_since(since_id)
    archive_notes.exclude_source('meta').newest_first.since(since_id)
  end

  def conversation_before(before_id)
    archive_notes.exclude_source('meta').newest_first.before(before_id)
  end

  def conversation_count(page = nil, no_of_records = 5)
    archive_notes.exclude_source('meta').size
  end

  def to_emails
    parent["to_emails"] if parent
  end

  def cc_email_hash
    ticket = archive_ticket_association.association_data["helpdesk_tickets"]
    cc_email = ticket["cc_email"] if ticket.present?
    if cc_email and cc_email.is_a?(Array)     
      {:cc_emails => cc_email, :fwd_emails => [], :reply_cc => cc_email}
    else
      cc_email
    end
  end
  alias :cc_email :cc_email_hash

  def helpdesk_tickets_association
    archive_ticket_association.association_data["helpdesk_tickets_association"]
  end

  def parent
    helpdesk_tickets_association["schema_less_ticket"]
  end

  SCHEMA_LESS_FIELDS.each do |alias_attribute, field_name|
    define_method "#{alias_attribute}" do
      parent[field_name]
    end
  end

  def custom_field
    account_ticket_fields.inject({}) do |hash, field| 
      hash[field.name] = custom_field_value(field.name) unless field.is_default_field?
      hash
    end
  end

  def non_text_custom_field
    account_ticket_fields.inject({}) do |hash, field| 
      if !field.is_default_field? and !NON_TEXT_FIELDS.include?(field.field_type)
        hash[field.name] = custom_field_value(field.name)
      end
      hash
    end
  end
  
  def account_ticket_fields
    @account_ticket_fields ||= Account.current.ticket_fields_with_nested_fields.includes([:picklist_values, :flexifield_def_entry])
  end

  def requester_info
    requester.get_info if requester
  end

  def requester_name
    requester.name || requester_info
  end

  def responder_name
    responder.nil? ? "No Agent" : responder.name
  end

  def included_in_cc?(from_email)
    (cc_email_hash) and  ((cc_email_hash[:cc_emails].any? {|email| email.include?(from_email.downcase) }) or 
                     (cc_email_hash[:fwd_emails].any? {|email| email.include?(from_email.downcase) }) or
                     included_in_to_emails?(from_email))
  end
  
  def group_name
    group.nil? ? "No Group" : group.name
  end
    
  def product_name
    self.product ? self.product.name : "No Product"
  end

  def company_name
    requester.company.nil? ? "No company" : requester.company.name
  end

  def included_in_to_emails?(from_email)
    (self.to_emails || []).select{|email_id| email_id.downcase.include?(from_email.downcase) }.present?
  end

  def to_liquid
    @archive_ticket_drop ||= Helpdesk::ArchiveTicketDrop.new self    
  end

  def status_updated_at
    ticket_association = archive_ticket_association.association_data["helpdesk_tickets_association"]
    ticket_association["ticket_states"]["status_updated_at"] if ticket_association
  end

  def custom_field_value(alias_name)
    ff_entry = Account.current.flexifield_def_entries.find_by_flexifield_alias(alias_name)
    return nil unless ff_entry

    field_name = ff_entry.flexifield_name
    ticket_association = archive_ticket_association.association_data["helpdesk_tickets_association"]
    ticket_association["flexifield"][field_name] if ticket_association
  end

  def ticket_states
    return Helpdesk::TicketState.new(archive_ticket_state) if archive_ticket_state
    archive_ticket_state = archive_ticket_association.association_data["helpdesk_tickets_association"]["ticket_states"]
    archive_ticket_state.delete(:id)
    archive_ticket_state.delete(:ticket_id)
    Helpdesk::TicketState.new(archive_ticket_state)
  end

  def to_s
    begin
    "#{subject} (##{display_id})"
    rescue ActiveRecord::MissingAttributeError
      "#{id}"
    end
  end

  def portal_host
    (self.product && !self.product.portal_url.blank?) ? self.product.portal_url : account.host
  end

  def description_with_attachments
    attachments.empty? ? description_html : 
        "#{description_html}\n\nTicket attachments :\n#{liquidize_attachments(attachments)}\n"
  end

  def liquidize_attachments(attachments)
    attachments.each_with_index.map { |a, i| 
      "#{i+1}. <a href='#{Rails.application.routes.url_helpers.helpdesk_attachment_url(a, :host => portal_host)}'>#{a.content_file_name}</a>"
      }.join("<br />")
  end

  def encode_display_id
    "[#{ticket_id_delimiter}#{display_id}]"
  end

  def ticket_id_delimiter
    delimiter = account.ticket_id_delimiter
    delimiter = delimiter.blank? ? '#' : delimiter
  end

  def requester_status_name
    Helpdesk::TicketStatus.translate_status_name(ticket_status, "customer_display_name")
  end

  def parent_ticket
    if parent[SCHEMA_LESS_FIELDS[:merge_ticket]]
      ticket = Helpdesk::Ticket.find_by_id(parent[SCHEMA_LESS_FIELDS[:merge_ticket]])
      return ticket if ticket
      archive_ticket = Helpdesk::ArchiveTicket.find_by_ticket_id(parent[SCHEMA_LESS_FIELDS[:merge_ticket]])
      return archive_ticket
    end
  end

  def sender_email
    parent[SCHEMA_LESS_FIELDS[:sender_email]]
  end

  [:due_by, :frDueBy, :fr_escalated, :isescalated].each do |attribute|
    define_method "#{attribute}" do
      archive_ticket_association.association_data["helpdesk_tickets"][attribute]
    end
  end

  def as_json(options = {}, deep=true)#TODO-RAILS3
    return super(options) unless options[:tailored_json].blank?
     
    options[:methods] = [:cc_email, :description, :description_html, :due_by, :frDueBy, 
      :fr_escalated, :isescalate, :status_name, :requester_status_name, :priority_name, :source_name, 
      :requester_name,:responder_name, :to_emails, :product_id] unless options.has_key?(:methods)
    
    unless options[:basic].blank? # basic prop is made sure to be set to true from controllers always.
      options[:only] = [:display_id, :subject, :deleted]
      json_hsh = super options
      return json_hsh
    end
    
    if deep
      self[:notes] = self.archive_notes
      options[:methods].push(:attachments)
      options[:include] = options[:include] || {}
      options[:include][:tags] = {:only => [:name]} if options[:include].is_a? Hash
    end
    options[:except] = [:account_id, :archive_created_at, :archive_updated_at]
    options[:methods].push(:custom_field)
    json_hash = super options.merge(:root => 'helpdesk_archive_ticket')
    json_hash
  end

  def to_xml(options = {})
    options[:indent] ||= 2
    xml = options[:builder] ||= ::Builder::XmlMarkup.new(:indent => options[:indent])
    xml.instruct! unless options[:skip_instruct]

    unless options[:basic].blank? #to give only the basic properties[basic prop set from 
      return super(:builder =>xml,:skip_instruct => true,:only =>[:display_id,:subject,:deleted],
          :methods=>[:status_name, :requester_status_name, :priority_name, :source_name, :requester_name, :responder_name])
    end
    ticket_attributes = [:archive_notes, :attachments]
    ticket_attributes = { :archive_notes => {},:attachments => {},:tags=> { :only => [:name] }}
    ticket_attributes = [] if options[:shallow]
    super(:builder => xml, :root => "helpdesk-archived-ticket", 
      :skip_instruct => true, :include => ticket_attributes, 
      :except => [:account_id, :import_id, :archive_created_at, :archive_updated_at], 
      :methods=>[:description, :description_html, :status_name, :requester_status_name, :priority_name, :source_name, :requester_name, :responder_name, :product_id]) do |xml|
      xml.to_emails do
        self.to_emails.each do |emails|
          xml.tag!(:to_email, emails)
        end
      end
      xml.custom_field do
        self.account.ticket_fields.custom_fields.each do |field|
          begin
           value = custom_field_value(field.name) 
           xml.tag!(field.name.gsub(/[^0-9A-Za-z_]/, ''), value) unless value.blank?

           if(field.field_type == "nested_field")
              field.nested_ticket_fields.each do |nested_field|
                nested_field_value = custom_field_value(nested_field.name)
                xml.tag!(nested_field.name.gsub(/[^0-9A-Za-z_]/, ''), nested_field_value) unless nested_field_value.blank?
              end
           end
         
         rescue
           end 
        end
      end
     end
  end

end
