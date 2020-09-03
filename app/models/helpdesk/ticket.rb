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
  include Redis::RoundRobinRedis
  include Reports::TicketStats
  include Helpdesk::TicketsHelperMethods
  include ActionView::Helpers::TranslationHelper
  include Helpdesk::TicketActivities, Helpdesk::TicketCustomFields, Helpdesk::TicketNotifications
  include Helpdesk::Services::Ticket
  include BusinessHoursCalculation
  include AccountConstants
  include RoundRobinCapping::Methods
  include MemcacheKeys
  include TicketConstants

  SCHEMA_LESS_ATTRIBUTES = ["product_id","to_emails","product", "skip_notification",
                            "header_info", "st_survey_rating", "survey_rating_updated_at", "trashed",
                            "access_token", "escalation_level", "sla_policy_id", "sla_policy", "manual_dueby", "sender_email",
                            "parent_ticket", "reports_hash","sla_response_reminded","sla_resolution_reminded", "dirty_attributes",
                            "sentiment", "spam_score", "dynamodb_range_key", "failure_count", "subsidiary_tkts_count",
                            "last_customer_note_id", "nr_updated_at", "nr_escalation_level", "nr_violated", 'tweet_type', 'fb_msg_type']

  TICKET_STATE_ATTRIBUTES = ["opened_at", "pending_since", "resolved_at", "closed_at", "first_assigned_at", "assigned_at",
                             "first_response_time", "requester_responded_at", "agent_responded_at", "group_escalated",
                             "inbound_count", "status_updated_at", "sla_timer_stopped_at", "outbound_count", "avg_response_time",
                             "first_resp_time_by_bhrs", "resolution_time_by_bhrs", "avg_response_time_by_bhrs", "resolution_time_updated_at", "on_state_time"]

  TICKET_BLACKLISTED_ATTRIBUTES = ['override_exchange_model'].freeze

  SLA_DATETIME_ATTRIBUTES = ['due_by', 'frDueBy', 'nr_due_by'].freeze

  TICKET_SLA_ATTRIBUTES = ['isescalated', 'fr_escalated', 'nr_escalated', 'escalation_level'].freeze

  OBSERVER_ATTR = []
  self.table_name = "helpdesk_tickets"

  serialize :cc_email

  concerned_with :associations, :validations, :presenter, :callbacks,
                 :rabbitmq, :permissions, :esv2_methods, :count_es_methods,
                 :round_robin_methods, :association_methods, :skill_based_round_robin,
                 :sla_calculation_methods, :kairos_methods, :presenter_helper

  spam_watcher_callbacks :user_column => "requester_id", :import_column => "import_id"
  #zero_downtime_migration_methods :methods => {:remove_columns => [ "description", "description_html"] }

  #by Shan temp
  attr_accessor :email, :name, :custom_field ,:customizer, :nscname, :twitter_id, :external_id,
    :requester_name, :meta_data, :disable_observer, :highlight_subject, :highlight_description,
    :phone , :facebook_id, :send_and_set, :archive, :required_fields, :disable_observer_rule,
    :disable_activities, :tags_updated, :system_changes, :activity_type, :misc_changes,
    :round_robin_assignment, :related_ticket_ids, :tracker_ticket_id, :unique_external_id, :assoc_parent_tkt_id,
    :sbrr_turned_on, :status_sla_toggled_to, :replicated_state, :skip_sbrr_assigner, :bg_jobs_inline,
    :sbrr_ticket_dequeued, :sbrr_user_score_incremented, :sbrr_fresh_ticket, :skip_sbrr, :model_changes,
    :schedule_observer, :required_fields_on_closure, :observer_args, :skip_sbrr_save,
    :sbrr_state_attributes, :escape_liquid_attributes, :update_sla, :sla_on_background,
    :sla_calculation_time, :disable_sla_calculation, :import_ticket, :ocr_update, :skip_ocr_sync,
    :custom_fields_hash, :thank_you_note_id, :perform_post_observer_actions, :prime_ticket_args, :current_note_id,
    :bulk_updation, :old_last_interaction_id, :old_tag_ids, :return_old_tag_ids, :sla_time_changes,
    :enqueue_va_actions

    # :skip_sbrr_assigner and :skip_sbrr_save can be combined together if needed.
    # Added :system_changes, :activity_type, :misc_changes for activity_revamp -
    # - will be clearing these after activity publish.

#  attr_protected :attachments #by Shan - need to check..

  attr_protected :account_id, :display_id, :attachments #to avoid update of these properties via api.

  attr_reader :sbrr_exec_obj

  alias_attribute :company_id, :owner_id
  alias_attribute :skill_id, :sl_skill_id
  alias_attribute :created_during, :created_at # to support the created_at for dispatcher rule

  scope :created_at_inside, -> (start, stop) {
    where([" helpdesk_tickets.created_at >= ? and helpdesk_tickets.created_at <= ?", start, stop])
  }
  
  scope :resolved_at_inside, -> (start, stop) {
    where([" helpdesk_tickets.resolved_at >= ? and helpdesk_tickets.resolved_at <= ?", start, stop]).
    joins([:ticket_states,:requester])
  }

  scope :resolved_and_closed_tickets, -> { where(status: [RESOLVED,CLOSED]) }

  scope :user_open_tickets, -> (user) {
    where(
      status: OPEN,
      requester_id: user.id
    )
  }

  scope :all_company_tickets, -> (company_id) {
    where(owner_id: company_id)
  }

  scope :all_user_tickets, -> (user_id) { where(requester_id: user_id) }

  scope :contractor_tickets, -> (user_id, company_ids, operator) {
    if user_id.present?
      where("helpdesk_tickets.requester_id = ? #{operator} helpdesk_tickets.owner_id in (?)",
                  user_id, company_ids)
    else
      where("helpdesk_tickets.owner_id in (?)", company_ids)
    end
  }

  TICKET_STATES_JOIN_SQL = %(INNER JOIN helpdesk_ticket_states ON
    helpdesk_tickets.id = helpdesk_ticket_states.ticket_id AND
    helpdesk_tickets.account_id = helpdesk_ticket_states.account_id).freeze

  scope :company_tickets_resolved_on_time, -> (company_id) {
    joins(TICKET_STATES_JOIN_SQL).
    where(["helpdesk_tickets.due_by >  helpdesk_ticket_states.resolved_at AND helpdesk_tickets.owner_id = ?",company_id])
  }

  scope :resolved_on_time, -> {
    joins(TICKET_STATES_JOIN_SQL).
    where("helpdesk_tickets.due_by >  helpdesk_ticket_states.resolved_at")
  }

  scope :first_call_resolution, -> {
    joins(TICKET_STATES_JOIN_SQL).
    where('(helpdesk_ticket_states.resolved_at IS NOT NULL) 
            AND helpdesk_ticket_states.inbound_count = 1')
  }

  scope :company_first_call_resolution, -> (company_id) {
    joins(TICKET_STATES_JOIN_SQL).
    where([%(helpdesk_ticket_states.resolved_at IS NOT NULL
              AND helpdesk_ticket_states.inbound_count = 1 
              AND helpdesk_tickets.owner_id = ?),company_id])
  }

  scope :newest, -> (num) { limit(num).order('helpdesk_tickets.created_at DESC') }
  scope :updated_in, -> (duration) { where(["helpdesk_tickets.updated_at > ?", duration]) }
  scope :created_in, -> (duration) { where(["helpdesk_tickets.created_at > ?", duration]) }

  scope :visible, -> { where(["spam=? AND helpdesk_tickets.deleted=? AND status > 0", false, false]) }
  scope :unresolved, -> { where(["helpdesk_tickets.status not in (#{RESOLVED}, #{CLOSED})"]) }
  scope :assigned_to, -> (agent) { where(responder_id: agent.id) }
  scope :requester_active, -> (user) {
    where(requester_id: user.id).
    order('helpdesk_tickets.created_at DESC')
  }
  
  scope :requester_latest_tickets, -> (user, duration) {
    where([ "requester_id=? and helpdesk_tickets.created_at > ?",
      user.id, duration ]).
    order('helpdesk_tickets.created_at DESC')
  }

  scope :forward_setup_latest_tickets, -> (requester, email, duration) {
    where(['requester_id=? and to_email=? and helpdesk_tickets.created_at > ?', requester.id, email, duration]).
    order('helpdesk_tickets.created_at DESC')
  }

  scope :requester_completed, -> (user) {
    where([ "requester_id=? and status in (#{RESOLVED}, #{CLOSED})",
      user.id ])
  }

  scope :latest_tickets, -> (updated_at) { where(["helpdesk_tickets.updated_at > ?", updated_at]) }

  scope :with_tag_names, -> (tag_names) {
    joins(:tags).
    select('helpdesk_tickets.id').
    where(["helpdesk_tags.name in (?)",tag_names])
  }

  scope :twitter_dm_tickets, -> (twitter_handle_id) {
    joins("INNER JOIN social_tweets on helpdesk_tickets.id = social_tweets.tweetable_id and
      helpdesk_tickets.account_id = social_tweets.account_id").
    where(["social_tweets.tweetable_type = ? and social_tweets.tweet_type = ? and social_tweets.twitter_handle_id =?",
      'Helpdesk::Ticket','dm', twitter_handle_id])
  }

  scope :spam_created_in, -> (user) {
    where(["helpdesk_tickets.created_at > ? and helpdesk_tickets.spam = true and requester_id = ?", 
      user.deleted_at, user.id]) 
  }

  scope :with_requester, -> (search_string) {
    joins(%(INNER JOIN users ON users.id = helpdesk_tickets.requester_id and
      users.account_id = helpdesk_tickets.account_id and users.deleted = false)).
    where(["users.name like ? and helpdesk_tickets.deleted is false","%#{search_string}%" ]).
    select("helpdesk_tickets.*, users.name as requester_name").
    order("helpdesk_tickets.status, helpdesk_tickets.created_at DESC").
    limit(1000)
  }

  scope :all_article_tickets, -> {
    joins(%(INNER JOIN article_tickets ON article_tickets.ticketable_id = helpdesk_tickets.id and
                    article_tickets.ticketable_type = 'Helpdesk::Ticket' and
                    article_tickets.account_id = helpdesk_tickets.account_id)).
    order("`article_tickets`.`id` DESC")
  }

  # The below scope "for_user_articles" HAS to be used along with "all_article_tickets"
  # Otherwise, the condition and hence the query would fail.
  scope :for_user_articles, -> (article_ids) {
    where(["`article_tickets`.`article_id` IN (?)", article_ids])
  }

  scope :mobile_filtered_tickets, -> (display_id, limit, order_param) {
    where(["display_id > (?)",display_id]).
    limit(limit).
    order(order_param)
  }

  scope :group_escalate_sla, -> (due_by) {
    select("helpdesk_tickets.*").
    joins("INNER JOIN helpdesk_ticket_states
      ON helpdesk_tickets.id = helpdesk_ticket_states.ticket_id
      AND helpdesk_tickets.account_id = helpdesk_ticket_states.account_id
      INNER JOIN groups ON groups.id = helpdesk_tickets.group_id AND
      groups.account_id =  helpdesk_tickets.account_id").
    where(['DATE_ADD(helpdesk_tickets.created_at,INTERVAL groups.assign_time SECOND) <=?
      AND group_escalated=? AND status=? AND helpdesk_ticket_states.first_assigned_at IS ?',
      due_by,false,Helpdesk::Ticketfields::TicketStatus::OPEN,nil])
  }

  scope :response_sla, -> (account,due_by) {
    select("helpdesk_tickets.*").
    joins(TICKET_STATES_JOIN_SQL).
    where(["frDueBy <=? AND fr_escalated=? AND status IN (?) AND
      helpdesk_ticket_states.first_response_time IS ? AND source != ?",
      due_by,false,Helpdesk::TicketStatus::donot_stop_sla_statuses(account),nil,
      Account.current.helpdesk_sources.ticket_source_keys_by_token[:outbound_email]])
  }

  scope :response_reminder, -> (sla_rule_ids) {
    select("helpdesk_tickets.*").
    joins("INNER JOIN helpdesk_schema_less_tickets 
            ON helpdesk_tickets.account_id = helpdesk_schema_less_tickets.account_id  
              AND helpdesk_tickets.id = helpdesk_schema_less_tickets.ticket_id").
    where(["helpdesk_schema_less_tickets.boolean_tc04=? AND helpdesk_schema_less_tickets.long_tc01 in (?) ",
            false,sla_rule_ids])
  }

  scope :resolution_sla, -> (account, due_by) {
    select("helpdesk_tickets.*").
    where(['due_by <=? AND isescalated=? AND status IN (?) AND source != ?',
                due_by,false, 
                Helpdesk::TicketStatus::donot_stop_sla_statuses(account),
                Account.current.helpdesk_sources.ticket_source_keys_by_token[:outbound_email]])
  }

  scope :resolution_reminder, -> (sla_rule_ids) {
    select("helpdesk_tickets.*").
    joins("INNER JOIN helpdesk_schema_less_tickets 
            ON helpdesk_tickets.account_id = helpdesk_schema_less_tickets.account_id  
              AND helpdesk_tickets.id = helpdesk_schema_less_tickets.ticket_id").
    where(["helpdesk_schema_less_tickets.boolean_tc05=? AND helpdesk_schema_less_tickets.long_tc01 in (?) ",
            false,sla_rule_ids])
  }

  scope :next_response_sla, ->(account, due_by) {
    select('helpdesk_tickets.*').
    where(["nr_due_by <=? AND nr_escalated=? AND status IN (?) AND source != ?",
                            due_by,false,Helpdesk::TicketStatus::donot_stop_sla_statuses(account),
                            Account.current.helpdesk_sources.ticket_source_keys_by_token[:outbound_email]])
  }

  scope :next_response_reminder, ->(sla_rule_ids) {
    select('helpdesk_tickets.*').
    joins('inner join helpdesk_schema_less_tickets on helpdesk_tickets.account_id = helpdesk_schema_less_tickets.account_id  AND
                            helpdesk_tickets.id = helpdesk_schema_less_tickets.ticket_id').
    where('nr_reminded=? AND helpdesk_schema_less_tickets.long_tc01 in (?)', false, sla_rule_ids)
  }

  scope :not_associated, -> { where(association_type: nil) }

  scope :associated_tickets, -> (association_type) {
    where(association_type: TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[association_type])
  }

  scope :unassigned, -> { where("helpdesk_tickets.responder_id is NULL") }

  scope :sla_on_tickets, -> (status_ids) {
    where(status: status_ids)
  }

  scope :agent_tickets, -> (status_ids, user_id) {
    where(
      status: status_ids,
      responder_id: user_id
    )
  }

  scope :associated_with_skill, -> (skill_id) {
    where(sl_skill_id: skill_id)
  }

  scope :next_autoplay_ticket, -> (account,responder_id) {
    select("helpdesk_tickets.display_id").
    where(
      status: Helpdesk::TicketStatus::donot_stop_sla_statuses(account),
      responder_id: responder_id
    ).
    limit(1).
    order("helpdesk_tickets.due_by ASC")
  }

  SCHEMA_LESS_ATTRIBUTES.each do |attribute|
    define_method("#{attribute}") do
      build_schema_less_ticket unless schema_less_ticket
      schema_less_ticket.safe_send(attribute)
    end

    define_method("#{attribute}?") do
      build_schema_less_ticket unless schema_less_ticket
      schema_less_ticket.safe_send(attribute)
    end

    define_method("#{attribute}=") do |value|
      build_schema_less_ticket unless schema_less_ticket
      schema_less_ticket.safe_send("#{attribute}=", value)
    end
  end

  TICKET_STATE_ATTRIBUTES.each do |attribute|
    define_method("#{attribute}") do
      if ticket_states
        ticket_states.safe_send(attribute)
      else
        # ticket_states should not be nil. Added for backward compatibility
        NewRelic::Agent.notice_error("ticket_states is nil for acc - #{Account.current.id} - #{self.id}")
        nil
      end
    end
  end

  def inbound_count=(count)
    ticket_states.inbound_count = count
  end

  def outbound_count=(count)
    ticket_states.outbound_count = count
  end

  def agent_availability=(available)
    agent.available = available if agent.present?
  end

  class << self # Class Methods

    def mobile_filtered_tickets(query_string,display_id,order_param,limit_val)
      if display_id != 0
        where(query_string,display_id).order(order_param).limit(limit_val)
      else
        order(order_param).limit(limit_val)
      end
    end

    def find_by_param(token, account, options = {})
      where(display_id: token, account_id: account.id).includes(options).first
    end

    def use_index(index)
      from("#{self.table_name} USE INDEX(#{index})")
    end

    def find_all_by_param(token)
      where(display_id: token).to_a
    end

    def extract_id_token(text, delimeter)
      pieces = text.match(Regexp.new("\\[#{delimeter}([0-9]*)\\]")) #by Shan changed to just numeric
      pieces && pieces[1]
    end

    def search_display(ticket)
      "#{ticket.subject} (##{ticket.display_id})"
    end

    def default_cc_hash
      { :cc_emails => [], :fwd_emails => [], :reply_cc => [], :tkt_cc => [], :bcc_emails => [] }
    end

  end

  def subsidiary_tkts_count
   if prime_ticket?
     (count = schema_less_ticket.subsidiary_tkts_count) ? count : associated_tickets_count
   end
  end

  def requester_sender_email_valid?
    requester_emails = requester.emails
    requester_emails.present? && requester_emails.include?(sender_email)
  end

  def properties_updated?
    changed? || schema_less_ticket_updated? || custom_fields_updated? || tags_updated
  end

  def skill_name
    self.skill.try(:name)
  end

  def model_changes
    @model_changes ||= {}
  end

  def sla_calculation_time
    @sla_calculation_time ||= Time.zone.now
  end

  def sbrr_state_attributes
    @sbrr_state_attributes ||= attributes.symbolize_keys.slice(*TicketConstants::NEEDED_SBRR_ATTRIBUTES)
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

  def translated_status_name
    translation_record = ticket_status.ticket_field.translation_record
    Helpdesk::TicketStatus.translate_status_name(ticket_status, nil, translation_record)
  end

  def requester_status_name
    Helpdesk::TicketStatus.translate_status_name(ticket_status, "customer_display_name")
  end

  def twitter?
    source == Account.current.helpdesk_sources.ticket_source_keys_by_token[:twitter] and (tweet) and (tweet.twitter_handle)
  end

  def email?
    source == Account.current.helpdesk_sources.ticket_source_keys_by_token[:email]
  end

  def show_facebook_reply?
    facebook? && !thread_key_nil?
  end

  def thread_key_nil?
    fb_post.message? && fb_post.facebook_page.use_thread_key? && fb_post.thread_key.nil?
  end

  def facebook?
     source == Account.current.helpdesk_sources.ticket_source_keys_by_token[:facebook] and (fb_post) and (fb_post.facebook_page)
  end

  def facebook_realtime_message?
    fb_post.realtime_message?
  end

  #This is for mobile app since it expects twitter handle & facebook page and not a boolean value
  def is_twitter
    source == Account.current.helpdesk_sources.ticket_source_keys_by_token[:twitter] ? (tweet and tweet.twitter_handle) : nil
  end

  def is_facebook
    source == Account.current.helpdesk_sources.ticket_source_keys_by_token[:facebook] ? (fb_post and fb_post.facebook_page) : nil
  end

  def bot?
    source == Account.current.helpdesk_sources.ticket_source_keys_by_token[:bot]
  end
  alias :is_bot :bot?

  def fb_replies_allowed?
    facebook? and !fb_post.reply_to_comment? and !thread_key_nil?
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
    source == Account.current.helpdesk_sources.ticket_source_keys_by_token[:mobihelp]
  end

  def outbound_email?
    (source == Account.current.helpdesk_sources.ticket_source_keys_by_token[:outbound_email]) && Account.current.compose_email_enabled?
  end

  def parent_ticket?
    self.associated_ticket? && TicketConstants::TICKET_ASSOCIATION_TOKEN_BY_KEY[self.association_type] == :assoc_parent
  end

  def service_task?
    ticket_type == Admin::AdvancedTicketing::FieldServiceManagement::Constant::SERVICE_TASK_TYPE
  end

  # Fetch NER data from cache.
  def fetch_ner_data
    key = NER_ENRICHED_NOTE % { :account_id => self.account_id , :ticket_id => self.id }
    MemcacheKeys.get_from_cache(key)
  end

  def fetch_latest_cf_handle(cf_obj)
    self.canned_form_handles.where(canned_form_id: cf_obj.id).last
  end

  def duplicate(original_attributes)
    self.flexifield
    self.ticket_states
    dup_ticket = self.dup
    dup_ticket.id = self.id
    dup_ticket.flexifield = self.flexifield.dup
    dup_ticket.flexifield.denormalized_flexifield = self.flexifield.denormalized_flexifield.dup
    dup_ticket.schema_less_ticket = self.schema_less_ticket.dup
    dup_ticket.ticket_states = self.ticket_states.dup
    dup_ticket.ticket_body = self.ticket_body
    original_attributes.each do |field, value|
      case field
      when :last_interaction
        dup_ticket.old_last_interaction_id = value
      when :tag_ids
        dup_ticket.old_tag_ids = value
        dup_ticket.return_old_tag_ids = true
      when :agent_availability
        if dup_ticket.responder.present? && dup_ticket.responder.agent.present?
          dup_ticket.responder.agent.old_agent_availability = value
          dup_ticket.responder.agent.return_old_agent_availability = true
        end
      else
        dup_ticket.safe_send("#{field}=", value) rescue nil
      end
    end
    dup_ticket
  end

  # Create/Fetch canned form handle

  def create_or_fetch_canned_form(cf_obj)
    Sharding.run_on_master do
      latest_cf_handle = fetch_latest_cf_handle(cf_obj)

      # If there is any unused CF handle url, use it. Otherwise, create a new one.
      if latest_cf_handle.nil? || latest_cf_handle.response_note_id
        handle = cf_obj.canned_form_handles.build(ticket_id: self.id)

        unless handle.save
          Rails.logger.info "Error While saving canned form handle - #{handle.errors}"
          return nil
        else
          return handle
        end
      end

        return latest_cf_handle
    end
  end

  #This method will return the user who initiated the outbound email
  #If it doesn't exist, returning requester.
  def outbound_initiator
    return requester unless outbound_email?
    begin
      meta_note = self.notes.find_by_source(Account.current.helpdesk_sources.note_source_keys_by_token["meta"])
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

  def sla_policy_name
    sla_policy.try(:name)
  end

  def get_access_token #for generating access_token for old tickets
    set_token
    schema_less_ticket.update_access_token(self.access_token) # wrote a separate method for avoiding callback
  end

  def source=(val)
    self[:source] = Account.current.helpdesk_sources.ticket_source_keys_by_token[val] || val
  end

  def source_name
    return TicketConstants.translate_source_name(source) unless Account.current.ticket_source_revamp_enabled?

    ticket_source.translated_source_name
  end

  def association_type_name
    TicketConstants.translate_association_type_name(association_type) unless association_type.nil?
  end

  def nickname
    subject
  end

  def chat?
    source == Account.current.helpdesk_sources.ticket_source_keys_by_token[:chat]
  end

  def requester_info
    requester.get_info if requester
  end

  def requester_phone
    (requester_has_phone?)? requester.phone : requester.mobile if requester
  end

  def not_editable?
    requester and !requester_has_email? and !requester_has_phone? and !requester_has_external_id?
  end

  def requester_has_email?
    (requester) and (requester.email.present?)
  end

  def requester_has_phone?
    requester and requester.phone.present?
  end

  def requester_has_external_id?
    account.unique_contact_identifier_enabled? ? (requester and requester.unique_external_id.present?) : false
  end

  def encode_display_id
    "[#{ticket_id_delimiter}#{display_id}]"
  end

  def conversation(page = nil, no_of_records = 5, includes_associations=[])
    includes_associations = note_preload_options if includes_associations.blank?
    notes.conversations.newest_first.includes(includes_associations).paginate(page: page, per_page: no_of_records)
  end

  def conversation_since(since_id)
    notes.conversations.since(since_id).includes(note_preload_options)
  end

  def conversation_before(before_id)
    notes.conversations.newest_first.before(before_id).includes(note_preload_options)
  end

  def conversation_count(page = nil, no_of_records = 5)
    notes.conversations.size
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
    time_sheets.map(&:running_time).sum
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
    return set_account_time_zone unless account.multiple_business_hours_enabled?
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
    cc_email_hash && ((cc_email_hash[:cc_emails].any? { |email| email.downcase.include?(from_email.downcase) }) ||
                     (cc_email_hash[:fwd_emails].any? { |email| email.downcase.include?(from_email.downcase) }) ||
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

  def friendly_reply_email_config
    (email_config && email_config.active) ? email_config : account.primary_email_config
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

  def tag_names= updated_tag_names
    unless updated_tag_names.nil? # Check only nil so that empty string will remove all the tags.
      updated_tag_names = updated_tag_names.split(",").map(&:strip).reject(&:empty?)
      self.tags = account.tags.assign_tags(updated_tag_names)
    end
  end

  #Some hackish things for virtual agent rules.
  def tag_names
    tags.collect { |tag| tag.name }
  end

  def tag_ids
    return old_tag_ids if return_old_tag_ids

    tag_uses.pluck(:tag_id)
  end

  def ticket_tags
    tag_names.join(',')
  end

  def ticket_survey_results
    if Account.current.new_survey_enabled?
      custom_survey_results.sort_by(&:id).last.try(:text)
    else
      survey_results.sort_by(&:id).last.try(:text)
    end
  end

  def subject_or_description
    [subject, description]
  end

  def spam_or_deleted?
    self.spam || self.deleted
  end

  def from_email
    self.sender_email.present? ? self.sender_email : requester.email
  end

  def ticlet_cc
    cc_email.nil? ? [] : (cc_email[:tkt_cc] || cc_email[:cc_emails])
  end
  alias_method :ticket_cc, :ticlet_cc

  def contact_name
    requester.name if requester
  end

  def company_name
    company ? company.name : "No company"
  end

  def last_interaction_note
    notes.visible.newest_first.exclude_source(['feedback', 'meta', 'forward_email', 'summary']).first
  end

  def last_interaction
    if old_last_interaction_id.present?
      notes.find_by_id(old_last_interaction_id).try(:body).to_s
    else
      last_interaction_note.try(:body).to_s
    end
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

  def description
    ticket_body && ticket_body.description
  end

  def description_html
    ticket_body && ticket_body.description_html
  end

  def description_with_attachments
    all_attachments.empty? ? description_html :
        "#{description_html}\n\nTicket attachments :\n#{liquidize_attachments(all_attachments)}\n"
  end

  def liquidize_attachments(all_attachments)
    all_attachments.each_with_index.map { |a, i|
      "#{i+1}. <a href='#{Rails.application.routes.url_helpers.helpdesk_attachment_url(a, :host => portal_host)}'>#{a.content_file_name}</a>"
      }.join("<br />") #Not a smart way for sure, but donno how to do this in RedCloth?
  end

  def latest_public_comment
    notes.conversations.public_notes.newest_first.first
  end

  def latest_private_comment
    notes.conversations.private_notes.newest_first.first
  end

  def liquidize_comment(comm, html=true)
    if comm
      c_descr = "#{comm.user ? comm.user.name : 'System'} : #{html ? comm.body_html : comm.body}"
      all_attachments = nil
      if html && (all_attachments = comm.all_attachments).present?
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
      ticket_states_included?(attribute) || custom_field_aliases.include?(attribute.to_s.chomp('=').chomp('?'))
  end

  def ticket_states_included?(attribute)
    # As we have already defined TICKET_STATE_ATTRIBUTES method individually,
    # not sure removing respond_to would break elsewhere so Blacklisting attributes
    (TICKET_BLACKLISTED_ATTRIBUTES.exclude?(attribute.to_s) && ticket_states.respond_to?(attribute))
  end

  def schema_less_attributes(attribute, args)
    build_schema_less_ticket unless schema_less_ticket
    args = args.first if args && args.is_a?(Array)
    (attribute.to_s.include? '=') ? schema_less_ticket.safe_send(attribute, args) : schema_less_ticket.safe_send(attribute)
  end

  def agent
    responder
  end

  def method_missing(method, *args, &block)
    begin
      super
    rescue NoMethodError, NameError => e
      return schema_less_attributes(method, args) if SCHEMA_LESS_ATTRIBUTES.include?(method.to_s.chomp("=").chomp("?"))
      return ticket_states.safe_send(method) if ticket_states.respond_to?(method)
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
        self.account.ticket_fields_including_nested_fields.custom_fields.non_secure_fields.each do |field|
          begin
           value = safe_send(field.name)
           xml.tag!(field.name.gsub(/[^0-9A-Za-z_]/, ''), value) unless value.blank?

           if(field.field_type == "nested_field")
              field.nested_ticket_fields.each do |nested_field|
                nested_field_value = safe_send(nested_field.name)
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

  def to_cc_emails
    [requester.email,cc_email[:cc_emails]]
  end

  def portal
    (self.product && self.product.portal) || account.main_portal
  end

  def portal_host
    (self.product && !self.product.portal_url.blank?) ? self.product.portal_url : account.host
  end

  def article_url_options(article)
    art_portal = (self.product && self.product.portal) || Account.current.main_portal
    unless art_portal.has_solution_category?(article.solution_folder_meta.solution_category_meta.id)
      art_portal = article.solution_folder_meta.solution_category_meta.portals.first
    end

    (art_portal && { :host => art_portal.host, :protocol => art_portal.url_protocol }) || {}
  end

  def article_url(article)
    url_opts = self.article_url_options(article)
    url_opts.merge!({ :url_locale => article.language.code }) if Account.current.multilingual?
    return url_opts[:host].present? && Rails.application.routes.url_helpers.support_solutions_article_url(article, url_opts)
  end

  def microresponse_only?
    twitter? || facebook? || mobihelp? || ecommerce?
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

  def internal_agent_name
    internal_agent.nil? ? "No Agent" : internal_agent.name
  end

  def internal_group_name
    internal_group.nil? ? "No Group" : internal_group.name
  end

  def cc_email_hash
    if cc_email.is_a?(Array)
      {:cc_emails => cc_email, :fwd_emails => [], :bcc_emails => [] , :reply_cc => cc_email}
    else
      cc_email
    end
  end

  def last_forwardable_note
    public_notes.where(['source NOT IN (?)', Account.current.helpdesk_sources.note_source_keys_by_token['feedback']]).last
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

    reply_to_all_emails = (cc_emails_array + to_emails_array).map{|email| trim_trailing_characters(parse_email_text(email)[:email])}.compact.uniq
    parsed_support_emails = account.parsed_support_emails

    parsed_support_emails.each do |support_email|
      reply_to_all_emails.delete_if {|to_email| (
        support_email.casecmp(to_email) == 0)
      }
    end

    reply_to_all_emails.delete_if {|to_email|
      (parse_email_with_domain(to_email.strip)[:domain] == account.full_domain)
    }
    reply_to_all_emails
  end

  def selected_reply_email
    account.pass_through_enabled? ? friendly_reply_email : account.default_friendly_email
  end



  def unsubscribed_agents
    user_ids = subscriptions.map(&:user_id)
    account.agents_details_from_cache.reject{ |a| user_ids.include?(a.id) }
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

  def trigger_autoplay?
    return false unless account.launched?(:autoplay)
    return false unless (User.current && User.current.agent? && User.current.agent.available?)
    can_trigger = false

    can_trigger = self.onhold_and_closed? if ticket_changes.has_key?(:status)
    can_trigger = ticket_changes[:responder_id][1] != User.current.try(:id) if ticket_changes.has_key?(:responder_id)

    can_trigger
  end

  #Ecommerce methods
  def ecommerce?
    source == Account.current.helpdesk_sources.ticket_source_keys_by_token[:ecommerce] && self.ebay_question.present?
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

  def custom_field_via_mapping
    return nil unless @custom_field || flexifield
    @custom_field ||= retrieve_ff_values_via_mapping
  end

  def custom_field_by_column_name
    @custom_field_by_column_name ||= begin
      custom_field.each_with_object({}) do |field, mapping|
        mapping[custom_field_column_name_mappings[field.first].to_s] = field.last
      end
    end
  end

  def custom_field= custom_field_hash
    self.custom_fields_hash = custom_field_hash
    @custom_field = new_record? ? custom_field_hash : nil
    unless new_record?
      assign_ff_values(custom_field_hash)
      @custom_field = nil
    end
  end

  def set_ff_value(ff_alias, ff_value, ff_def = nil)
    self.ff_def ||= ff_def if ff_def.present?
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

  def custom_field_column_name_mappings
    @custom_field_column_name_mappings ||= begin
      self.account.ticket_fields_with_nested_fields.custom_fields.each_with_object({}) { |f, a|
        a[f.name] = f.column_name.to_sym
        a
      }
    end
  end

  def resolution_status
    return '' unless !service_task? && [RESOLVED, CLOSED].include?(status)

    resolved_at.nil? ? "" : ((resolved_at < due_by)  ? t('export_data.in_sla') : t('export_data.out_of_sla'))
  end

  def first_response_status
    #Hack: for outbound emails, first response status needs to be blank.
    (outbound_email? or first_response_time.nil?) ? "" : ((first_response_time < frDueBy) ? t('export_data.in_sla') : t('export_data.out_of_sla'))
  end

  def every_response_status
    (nr_escalated || nr_violated?) ? t('export_data.out_of_sla') : (nr_violated.nil? ? '' : t('export_data.in_sla'))
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
    (self.twitter? or self.fb_replies_allowed? or self.from_email.present? or self.mobihelp? or self.allow_ecommerce_reply?)
  end

  def header_info_present?
    header_info.present? && header_info[:message_ids].present?
  end

  def support_ticket_path
    "#{url_protocol}://#{portal_host}/support/tickets/#{display_id}"
  end

  ## Methods related to agent as a requester starts here ###

  def agent_performed?(user)
    user.agent? && !agent_as_requester?(user.id)
  end

  def customer_performed?(user)
    user.customer? || agent_as_requester?(user.id)
  end

  def agent_as_requester?(user_id)
    requester_id == user_id && requester.agent?
  end

  ## Methods related to agent as a requester starts here ###

  def linked_to_integration?(installed_app)
    self.linked_applications.where(:id => installed_app.id).any?
  end

  # Used by API v2
  def self.filter_conditions(ticket_filter = nil, current_user = nil)
    {
      default: {
        conditions: ['helpdesk_tickets.created_at > ?', created_in_last_month ]
      },
      spam: {
        conditions: { spam: true }
      },
      deleted: {
        conditions: { deleted: true, helpdesk_schema_less_tickets: { boolean_tc02: false } },
        joins: :schema_less_ticket
      },
      new_and_my_open: {
        conditions: { status: OPEN,  responder_id: [nil, current_user.try(:id)] }
      },
      watching: {
          :conditions => {helpdesk_subscriptions: {user_id: current_user.id}},
          :joins => :subscriptions
      },
      requester_id: {
        conditions: { requester_id: ticket_filter.try(:requester_id) }
      },
      company_id: {
        conditions: { owner_id: ticket_filter.try(:company_id) }
      },
      updated_since: {
        conditions: ['helpdesk_tickets.updated_at >= ?', ticket_filter.try(:updated_since).try(:to_time).try(:utc)]
      }
    }
  end

  def self.created_in_last_month
    # created in last month filter takes up user time zone info also into account.
    in_user_time_zone { Time.zone.now.beginning_of_day.ago(1.month).utc }
  end

  def self.in_user_time_zone(&block)
    old_zone = Time.zone
    TimeZone.set_time_zone
    yield
  ensure
    Time.zone = old_zone
  end

  def self.ignore_primary_key
    if Account.current.launched?(:export_ignore_primary_key)
      self.from('helpdesk_tickets ignore key (primary)')
    else
      self.from('helpdesk_tickets')
    end
  end

  # Used update_column instead of touch because touch fires after commit callbacks from RAILS 4 onwards.
  def update_timestamp
    unless @touched || new_record?
      prev_updated_at = self.updated_at
      time_now = Time.zone.now
      self.update_column(:updated_at, time_now) # update_column can't be invoked in new record.
      self.sqs_manual_publish
      self.model_changes = { updated_at: [prev_updated_at, time_now] }
      self.manual_publish_to_central(nil, :update, {}, true)
    end
    @touched ||= true
  end

  def add_tag_activity(tag)
    self.tags_updated = true    # for ES search
    if self.misc_changes.present?
      self.misc_changes[:add_tag].present? ? self.misc_changes[:add_tag] << tag.name : self.misc_changes[:add_tag] = [tag.name]
    else
      self.misc_changes = {:add_tag => [tag.name]}
    end
  end

  def remove_tag_activity(tag)
    self.tags_updated = true    # for ES search
    if self.misc_changes.present?
      self.misc_changes[:remove_tag].present? ? self.misc_changes[:remove_tag] << tag.name : self.misc_changes[:remove_tag] = [tag.name]
    else
      self.misc_changes = {:remove_tag => [tag.name]}
    end
  end

  def all_attachments
    @all_attachments ||= begin
      resp_shared_attachments = self.attachments_sharable
      individual_attachments  = self.attachments
      individual_attachments + resp_shared_attachments
    end
  end

  # Moved here from note.rb
  def trigger_cc_changes(old_cc)
    new_cc      = self.cc_email.try(:dup)
    cc_changed  = if old_cc.nil?
      !old_cc.eql?(new_cc)
    else
      [:cc_emails, :fwd_emails].any? { |f| !(old_cc[f].uniq.sort.eql?(new_cc[f].uniq.sort)) }
    end

    self.cc_email_will_change! if cc_changed
  end

  def va_rules_after_save_actions
    @va_rules_after_save_actions ||= []
  end

  def draft
    @draft ||= TicketDraft.new(id)
  end

  def skill_id_column
    :sl_skill_id
  end

  def archive?
    false
  end
  alias :archive :archive?

  def ticket_was _changes = {}, _attributes = self.attributes, custom_attributes = []
    replicate_ticket :first, _changes, _attributes, custom_attributes
  end

  def ticket_is _changes = {}, _attributes = self.attributes, custom_attributes = []
    replicate_ticket :last, _changes, _attributes, custom_attributes
  end

  def replicate_ticket index, _changes = {}, _attributes = self.attributes, custom_attributes = [], _schema_less_ticket_changes = _changes
    ticket_replica = account.tickets.new #dup creates problems
    ticket_replica.id = id
    ticket_replica.display_id = display_id

    _attributes.each do |_attribute, value| #to work around protected attributes
      next if TicketConstants::SKIPPED_TICKET_CHANGE_ATTRIBUTES.include? _attribute.to_sym #skipping deprecation warning
      ticket_replica.safe_send("#{_attribute}=", value)
    end

    _changes ||= begin
      temp_changes = changes #calling changes builds a hash everytime
      temp_changes.present? ? temp_changes : previous_changes
    end
    _changes.each do |_attribute, change|
      if ticket_replica.respond_to?(_attribute) && (change.size == 2) #Hack for tags in model_changes
        ticket_replica.safe_send("#{_attribute}=", change.safe_send(index))
      end
    end
    ticket_replica.replicated_state = TicketConstants::TICKET_REPLICA[index]
    custom_attributes.each {|custom_attr| ticket_replica.safe_send("#{custom_attr}=", safe_send(custom_attr)) }

    ticket_replica.schema_less_ticket =
      schema_less_ticket.replicate_schema_less_ticket(index, _schema_less_ticket_changes)
    ticket_replica
  end

  def valid_internal_group?(ig_id = internal_group_id)
    return true if ig_id.blank?
    ticket_status.group_ids.include?(ig_id)
  end

  def valid_internal_agent?(ia_id = internal_agent_id)
    return true if ia_id.blank?
    valid_internal_group? && (internal_group.try(:agent_ids) || []).include?(ia_id)
  end

  def mint_url
    "#{url_protocol}://#{portal_host}/a/tickets/#{display_id}"
  end

  # overridden default setter method to take care of existing inline attachments
  def inline_attachment_ids=(attachment_ids)
    attachment_ids ||= []
    attachment_ids = attachment_ids.split(",") if attachment_ids.is_a? String
    attachment_ids = (inline_attachment_ids + attachment_ids).map(&:to_i).uniq
    super(attachment_ids)
  end

  def invoke_ticket_observer_worker(args)
    if trigger_thank_you_worker?(args)
      ::Freddy::DetectThankYouNoteWorker.perform_async(args)
      Rails.logger.info "Enqueueing DetectThankYouNoteWorker T :: #{id} , N :: #{args[:note_id]}"
    else
      job_id = if service_task?
                 ::Tickets::ServiceTaskObserverWorker.perform_async(args)
               else
                 ::Tickets::ObserverWorker.perform_async(args)
               end
      Va::Logger::Automation.set_thread_variables(Account.current.id, id, args[:doer_id], nil)
      Va::Logger::Automation.log("Triggering Observer, job_id=#{job_id}, info=#{args.inspect}", true)
      Va::Logger::Automation.unset_thread_variables
    end

  end

  def trigger_thank_you_worker?(args)
    return false unless args[:note_id].present? && !service_task?

    note = notes.find_by_id(args[:note_id])
    return false unless note.present?
    Account.current.detect_thank_you_note_enabled? && Account.current.thank_you_configured_in_automation_rules? && sla_timer_off_status? &&
      note.eligible_to_detect_thank_you?
  end

  def sla_timer_off_status?
    Helpdesk::TicketStatus.onhold_and_closed_statuses(Account.current).include? status
  end

  def has_active_forum_topic? # rubocop:disable PredicateName
    ticket_topic && ticket_topic.topic && !ticket_topic.topic.locked?
  end

  def add_forum_post(ticket_note)
    has_active_forum_topic? && ticket_topic.topic.create_post_from_ticket_note(ticket_note)
  end

  def rr_active
    !deleted && !spam && !ticket_status.stop_sla_timer
  end
  alias_method :rr_active?, :rr_active

  def round_robin_attributes
    { active: rr_active, agent_id: responder_id.to_s.presence, group_id: group_id.to_s.presence, assignment_params: assignment_params }
  end

  def assignment_params
    { created_at: created_at.to_i * 1000, response_due: expected_response_time.to_i * 1000, resolution_due: due_by.to_i * 1000 }
  end

  def expected_response_time
    nr_due_by.presence || frDueBy
  end

  def eligible_for_ocr?
    account.omni_channel_routing_enabled? && rr_active?
  end

  def eligible_for_ocr?
    account.omni_channel_routing_enabled? && rr_active?
  end

  def thank_you_note
    @thank_you_note ||= evaluate_on.notes.find_by_id(thank_you_note_id)
  end

  def update_email_received_at(received_at)
    return if received_at.blank?

    schema_less_ticket.header_info[:received_at] = received_at
  end

  def requester_language
    requester.language if requester
  end

  def prime_save
    round_robin_on_ticket_update(changes) if rr_allowed_on_update?
    ticket_changes = merge_changes(changes, changes.slice(:responder_id)) 
    update_old_group_capping(ticket_changes)
    sla_args = prime_ticket_args[:sla_args].try(:symbolize_keys) if prime_ticket_args.present?
    if sla_args && sla_args[:sla_on_background] && evaluate_on.is_in_same_sla_state?(sla_args[:sla_state_attributes])
      update_sla = true
      sla_calculation_time = sla_args[:sla_calculation_time]
    end
    skip_ocr_sync = true
    self.save
  end

  def custom_field_value(field_name)
    safe_send(field_name)
  end

  private
    def sphinx_data_changed?
      description_html_changed? || requester_id_changed? || responder_id_changed? || group_id_changed? || deleted_changed?
    end

    def send_agent_assigned_notification?(internal_notification = false)
      doer_id = Thread.current[:observer_doer_id]
      agent_changed, agent = internal_notification ? [@model_changes.key?(:internal_agent_id), internal_agent] :
          [@model_changes.key?(:responder_id), responder]

      agent_changed && agent && agent.id != doer_id && agent != User.current
    end

    def note_preload_options
      options = [:attachments, :note_body, :schema_less_note, :notable, :attachments_sharable, {:user => :avatar}, :cloud_files]
      options << :freshfone_call if Account.current.features?(:freshfone)
      options << :freshcaller_call if Account.current.has_feature?(:freshcaller)
      options << (Account.current.new_survey_enabled? ? {:custom_survey_remark =>
                    {:survey_result => [:survey_result_data, :agent, {:survey => :survey_questions}]}} : :survey_remark)
      options << :fb_post if facebook?
      options << :tweet if twitter?
      options
    end

  #Shared ownership methods

    def shared_ownership_fields_changed?
      internal_group_id_changed? or internal_agent_id_changed?
    end

  #Shared ownership methods ends here

    def benchmark_ticket_field_data
      time_taken = Benchmark.realtime { yield }
      Rails.logger.debug "Time taken: #{time_taken} Ticket: #{display_id} Account: #{account_id}"
    end

    # def rl_exceeded_operation
    #   key = "RL_%{table_name}:%{account_id}:%{user_id}" % {:table_name => self.class.table_name, :account_id => self.account_id,
    #                                                          :user_id => self.requester_id }
    #   $spam_watcher.perform_redis_op("rpush", ResourceRateLimit::NOTIFY_KEYS, key)
    # end

end
