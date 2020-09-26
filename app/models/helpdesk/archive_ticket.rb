# encoding: utf-8
require 'digest/md5'

class Helpdesk::ArchiveTicket < ActiveRecord::Base
  include TicketConstants
  include Helpdesk::TicketCustomFields
  include Search::ElasticSearchIndex
  include ArchiveTicketExportParams
  include Helpdesk::TicketActivities

  HELPDESK_TICKET_ATTRIBUTES = ['due_by', 'frDueBy', 'email_config_id', 'fr_escalated', 'nr_due_by', 'nr_escalated', 'nr_reminded', 'isescalated', 'spam', 'associates_rdb', 'urgent', 'trained', 'import_id', 'sl_skill_id', 'association_type'].freeze

  self.primary_key = :id
  belongs_to_account
  belongs_to :requester, :class_name => 'User'
  belongs_to :responder, :class_name => 'User', :conditions => 'users.helpdesk_agent = true'
  belongs_to :group

  belongs_to :company, :foreign_key => :owner_id

  has_many :archive_notes_old,
           :class_name => "Helpdesk::ArchiveNote",
           :dependent => :destroy

  has_many :notes, :inverse_of => :notable, :class_name => 'Helpdesk::Note', :as => 'notable', :dependent => :destroy # TODO-RAILS3 Need to cross check, :foreign_key => :id


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
  has_many :archive_time_sheets, :class_name => 'Helpdesk::TimeSheet',:as => 'workable',:dependent => :destroy, :order => "executed_at"
  has_many :time_sheets_with_users, :class_name => 'Helpdesk::TimeSheet',:as => 'workable', :order => "executed_at", :include => {:user => :avatar}
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

  has_one :article_ticket, as: :ticketable, dependent: :destroy
  has_one :article, through: :article_ticket
  
  belongs_to :ticket_status, :class_name =>'Helpdesk::TicketStatus', :foreign_key => "status", :primary_key => "status_id"
  belongs_to :product
  
  has_many :public_notes_old,
    :class_name => 'Helpdesk::ArchiveNote',
    :conditions => { :private =>  false, :deleted => false  }
  
  has_many :public_notes_new,
    :class_name => 'Helpdesk::Note', :as => 'notable',
    :conditions => { :private =>  false, :deleted => false  }
  
  has_flexiblefields :class_name => 'Flexifield', :as => :flexifield_set
  has_many_attachments
  has_many_cloud_files

  has_many :shared_attachments,
    :as => :shared_attachable,
    :class_name => 'Helpdesk::SharedAttachment',
    :dependent => :destroy

  has_many :attachments_sharable, :through => :shared_attachments, :source => :attachment

  delegate :active?, :open?, :is_closed, :closed?, :resolved?, :pending?, :onhold?,
    :onhold_and_closed?, :to => :ticket_status, :allow_nil => true

  delegate :first_assigned_at, :on_state_time, to: :ticket_states

  attr_protected :account_id
  attr_accessor :highlight_subject, :highlight_description, :archive_ticket_state, :custom_fields_hash

  alias_attribute :company_id, :owner_id

  concerned_with :rabbitmq, :attributes, :s3, :esv2_methods, :presenter

  belongs_to :ticket_source, class_name: 'Helpdesk::Source', foreign_key: 'source', primary_key: 'account_choice_id', inverse_of: :archive_tickets
  belongs_to :internal_group, class_name: 'Group'
  belongs_to :internal_agent, class_name: 'User', conditions: { helpdesk_agent: true }, inverse_of: :archive_tickets

  SORT_FIELDS = [
    [ :created_at , "tickets_filter.sort_fields.date_created"  ],
    [ :updated_at , "tickets_filter.sort_fields.last_modified" ],
    [ :priority   , "tickets_filter.sort_fields.priority"      ]
  ]
  SCHEMA_LESS_FIELDS = {
    sla_policy_id: 'long_tc01',
    merge_ticket: 'long_tc02',
    reports_hash: 'text_tc02',
    sender_email: 'string_tc03',
    trashed: 'boolean_tc02',
    product_id: 'product_id',
    header_info: 'text_tc01',
    sla_response_reminded: 'boolean_tc04',
    sla_resolution_reminded: 'boolean_tc05',
    escalation_level: 'int_tc02'
  }
  NON_TEXT_FIELDS = ["custom_text", "custom_paragraph"]


  scope :permissible , ->(user) { where(permissible_condition(user)) unless user.customer? }
  scope :requester_active, ->(user){ where("requester_id=?", user.id).order('created_at DESC') }

  scope :newest, ->(num){ order('created_at DESC').limit(num) }

  scope :all_company_tickets, ->(company_id){
    where(owner_id: company_id)
  }
  scope :all_user_tickets, ->(user_id) { where(requester_id: user_id) }

  scope :contractor_tickets, ->(user_id, company_ids, operator){
    if user_id.present?
      where("archive_tickets.requester_id = ? #{operator} archive_tickets.owner_id in (?)", 
                  user_id, company_ids)
    else
      where("archive_tickets.owner_id in (?)", company_ids)
    end
  }

  scope :created_at_inside, ->(start, stop) {
    where("archive_tickets.created_at >= ? and archive_tickets.created_at <= ?", start, stop)
  }
  # do we need this
  # validates_uniqueness_of :display_id, :scope => :account_id
  default_scope ->{ where(progress: false) }

  def all_attachments
    @all_attachments ||= begin
      shared_attachments = self.attachments_sharable
      individual_attachments = self.attachments
      individual_attachments + shared_attachments
    end
  end

  def self.permissible_condition user
    case Agent::PERMISSION_TOKENS_BY_KEY[user.agent.ticket_permission]
    when :assigned_tickets
      ["responder_id=?", user.id]
    when :group_tickets
      group_ids = user.access_all_agent_groups ? user.all_associated_group_ids : user.associated_group_ids
      ["group_id in (?) OR responder_id=?", group_ids, user.id]
    when :all_tickets
      []
    end
  end

  def self.sort_fields_options
    SORT_FIELDS.map { |i| [I18n.t(i[1]), i[0]] }
  end

  def self.find_by_param(token, account, options = {})
    # hack for maintaingin tickets which are alreadu archived
    # removing includes options as we have to determine
    where(display_id: token, account_id: account.id).first
  end

  def self.sort_fields_options_array 
    SORT_FIELDS.map { |i| i[0]}
  end

  def source_name
    return TicketConstants.translate_source_name(source) unless Account.current.ticket_source_revamp_enabled?

    ticket_source.translated_source_name
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

  def skill
    return @skill if defined?(@skill)

    @skill = account.skills.where(id: sl_skill_id).last
  end

  def email?
    source == account.helpdesk_sources.ticket_source_keys_by_token[:email]
  end

  def twitter?
    source == Account.current.helpdesk_sources.ticket_source_keys_by_token[:twitter] and (tweet) and (tweet.twitter_handle)
  end
  alias :is_twitter :twitter?

  def facebook?
     source == Account.current.helpdesk_sources.ticket_source_keys_by_token[:facebook] and (fb_post) and (fb_post.facebook_page)
  end
  alias :is_facebook :facebook?

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
    source == Account.current.helpdesk_sources.ticket_source_keys_by_token[:mobihelp]
  end

  def chat?
    source == Account.current.helpdesk_sources.ticket_source_keys_by_token[:chat]
  end

  def description
    archive_ticket_association.description
  end

  def description_html
    archive_ticket_association.description_html
  end

  def conversation(page = nil, no_of_records = 5, includes=[])
    includes = note_preload_options if includes.blank?
    archive_notes.conversations.newest_first.includes(includes).paginate(page: page, per_page: no_of_records)
  end

  def conversation_since(since_id)
    archive_notes.conversations.newest_first.since(since_id).includes(note_preload_options)
  end

  def conversation_before(before_id)
    archive_notes.conversations.newest_first.before(before_id).includes(note_preload_options)
  end

  def conversation_count(page = nil, no_of_records = 5)
    archive_notes.conversations.size
  end

  def to_emails
    parent["to_emails"] if parent
  end

  def cc_email_hash
    ticket = archive_ticket_association.association_data["helpdesk_tickets"]
    cc_email = ticket["cc_email"] if ticket.present?
    if cc_email and cc_email.is_a?(Array)
      {:cc_emails => cc_email, :fwd_emails => [], :reply_cc => cc_email}.with_indifferent_access
    else
      cc_email.with_indifferent_access if cc_email.is_a?(Hash)
    end
  end
  alias :cc_email :cc_email_hash
  
  def ticket_cc
    cc_email.nil? ? [] : (cc_email[:tkt_cc] || cc_email[:cc_emails])
  end

  def helpdesk_tickets_association
    archive_ticket_association.association_data["helpdesk_tickets_association"]
  end

  def parent
    helpdesk_tickets_association["schema_less_ticket"] || {}
  end

  SCHEMA_LESS_FIELDS.each do |alias_attribute, field_name|
    next if alias_attribute == "product_id"
    define_method "#{alias_attribute}" do
      parent[field_name]
    end
  end

  def product_id=(product_id)
    self.safe_send(:write_attribute,:product_id,product_id)
  end

  def product_id
    return self.read_attribute(:product_id) || parent["product_id"]
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
    cc_email_hash_value = cc_email_hash
    (cc_email_hash_value) and  ((cc_email_hash_value["cc_emails"].any? {|email| email.include?(from_email.downcase) }) or
                     (cc_email_hash_value["fwd_emails"].any? {|email| email.include?(from_email.downcase) }) or
                     included_in_to_emails?(from_email))
  end

  def group_name
    group.nil? ? "No Group" : group.name
  end

  def product_name
    self.product ? self.product.name : "No Product"
  end

  def company_name
    company.nil? ? "No company" : company.name
  end

  def included_in_to_emails?(from_email)
    (self.to_emails || []).select{|email_id| email_id.downcase.include?(from_email.downcase) }.present?
  end

  def to_liquid
    @archive_ticket_drop ||= Helpdesk::ArchiveTicketDrop.new self
  end

  def status_updated_at
    ticket_states.status_updated_at
  end

  def custom_field_value(alias_name)
    ff_entry = Account.current.flexifield_def_entries.find_by_flexifield_alias(alias_name)
    return nil unless ff_entry

    field_name = ff_entry.flexifield_name
    flexifield_data[field_name] if helpdesk_tickets_association
  end
  
  def flexifield_data
    helpdesk_tickets_association['flexifield'] || {}
  end
  
  def subscription_data
    helpdesk_tickets_association['subscriptions']
  end

  def ticket_states
    return Helpdesk::TicketState.new(archive_ticket_state) if archive_ticket_state
    archive_ticket_state = archive_ticket_association.association_data["helpdesk_tickets_association"]["ticket_states"] || {}
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

  def to_param 
    display_id ? display_id.to_s : nil
  end

  def portal_host
    (self.product && !self.product.portal_url.blank?) ? self.product.portal_url : account.host
  end

  def description_with_attachments
    all_attachments.empty? ? description_html :
        "#{description_html}\n\nTicket attachments :\n#{liquidize_attachments(all_attachments)}\n"
  end

  def liquidize_attachments(all_attachments)
    all_attachments.each_with_index.map { |a, i|
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

  def from_email
    self.sender_email.present? ? self.sender_email : requester.email
  end

  HELPDESK_TICKET_ATTRIBUTES.each do |attribute|
    define_method "#{attribute}" do
      attr_value = archive_ticket_association.association_data['helpdesk_tickets'][attribute]
      if Helpdesk::Ticket.columns_hash[attribute].type == :boolean && !attr_value.nil?
        ([1, true].include? attr_value) ? true : false
      else
        attr_value
      end
    end
  end

  def url_protocol
    if self.product && !self.product.portal_url.blank?
      self.product.portal.ssl_enabled? ? 'https' : 'http'
    else
      account.ssl_enabled? ? 'https' : 'http'
    end
  end

  def support_ticket_path
    "#{url_protocol}://#{portal_host}/support/tickets/archived/#{display_id}"
  end

  ## Methods related to agent as a requester starts here ##
  def customer_performed?(user)
    user.customer? || agent_as_requester?(user.id)
  end

  def agent_as_requester?(user_id)
    requester_id == user_id && requester.agent?
  end

  def agent_performed?(user)
    user.agent? && !agent_as_requester?(user.id)
  end

  def accessible_in_helpdesk?(user)
    user.privilege?(:manage_tickets) && (user.can_view_all_tickets? || restricted_agent_accessible?(user) || group_agent_accessible?(user))
  end

  def restricted_in_helpdesk?(user)
    agent_as_requester?(user.id) && !accessible_in_helpdesk?(user)
  end

  def group_agent_accessible?(user)
    user.group_ticket_permission && (responder_id == user.id || Account.current.agent_groups.where(:user_id => user.id, :group_id => group_id).present? )
  end

  def restricted_agent_accessible?(user)
    user.assigned_ticket_permission && responder_id == user.id
  end

  ## Methods related to agent as a requester ends here ##

  def archive?
    true
  end
  alias :archive :archive?

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
        self.account.ticket_fields_including_nested_fields.custom_fields.each do |field|
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


  def archive_notes
    current_shard = ActiveRecord::Base.current_shard_selection.shard.to_s
    if(ArchiveNoteConfig[current_shard] && (self.id <= ArchiveNoteConfig[current_shard].to_i))
      archive_notes_old
    else
      notes
    end
  end

  def public_notes
    current_shard = ActiveRecord::Base.current_shard_selection.shard.to_s
    if(ArchiveNoteConfig[current_shard] && (self.id <= ArchiveNoteConfig[current_shard].to_i))
      public_notes_old
    else
      public_notes_new
    end
  end

  def outbound_email?
    (source == Account.current.helpdesk_sources.ticket_source_keys_by_token[:outbound_email]) && Account.current.compose_email_enabled?
  end

    #This method will return the user who initiated the outbound email
  #If it doesn't exist, returning requester.
  def outbound_initiator
    return requester unless outbound_email?
    begin
      meta_note = self.archive_notes.find_by_source(Account.current.helpdesk_sources.note_source_keys_by_token["meta"])
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

  def shred_inline_images
    DeletedBodyObserver.write_to_s3(self.description_html, 'Helpdesk::ArchiveTicket', self.id)
    InlineImageShredder.perform_async({model_name: 'Helpdesk::ArchiveTicket', model_id: self.id})
  end

  def self.unscope_progress
    unscoped.where(account_id: Account.current.id)
  end

  private

    def note_preload_options
      options = [:attachments, :attachments_sharable, :cloud_files, {:user => :avatar}]
      options << :freshfone_call if Account.current.features?(:freshfone)
      options << :fb_post if facebook?
      options << :tweet if twitter?
      options
    end

end
