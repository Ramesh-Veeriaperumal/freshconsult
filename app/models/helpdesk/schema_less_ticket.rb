class Helpdesk::SchemaLessTicket < ActiveRecord::Base
	
	include BusinessHoursCalculation
	include Helpdesk::EmailFailureMethods
  include LockVersion::Utility

  self.locking_column = :int_tc05

  attr_reader :schema_less_was

  attr_accessor :retrigger_observer

	COUNT_COLUMNS_FOR_REPORTS = ["agent_reassigned", "group_reassigned", "reopened", 
                                  "private_note", "public_note", "agent_reply", "customer_reply"]
	
  	NOTE_COUNT_METRICS = ["private_note", "public_note", "agent_reply", "customer_reply"]

  COLUMN_TO_ATTRIBUTE_MAPPING = {
    :boolean_tc01     =>    :skip_notification,
    :text_tc01        =>    :header_info,
    :int_tc01         =>    :st_survey_rating,
    :datetime_tc01    =>    :survey_rating_updated_at,
    :boolean_tc02     =>    :trashed,
    :string_tc03      =>    :sender_email,
    :string_tc01      =>    :access_token,
    :int_tc02         =>    :escalation_level,
    :long_tc01        =>    :sla_policy_id,
    :boolean_tc03     =>    :manual_dueby,
    :long_tc02        =>    :parent_ticket,
    :text_tc02        =>    :reports_hash,
    :boolean_tc04     =>    :sla_response_reminded,
    :boolean_tc05     =>    :sla_resolution_reminded,
    :text_tc03        =>    :dirty_attributes,
    :text_tc04        =>    :additional_info
  }

  SERIALIZED_DB_COLUMNS = ['text_tc01', 'text_tc02', 'text_tc03', 'text_tc04', 'text_tc05']

  PRESENTER_FIELDS_MAPPING = { 'long_tc02' => 'parent_id' }.freeze

  COLUMN_TO_ATTRIBUTE_MAPPING.keys.each do |key|
    alias_attribute(COLUMN_TO_ATTRIBUTE_MAPPING[key], key)
  end

    LIFECYCLE_REPORTS_MAPPING = {"agent" => 'responder_id', 'group' => 'group_id', 'status' => 'status'}
    LIFECYCLE_REPORTS_COLUMNS = LIFECYCLE_REPORTS_MAPPING.keys
  
	self.table_name =  "helpdesk_schema_less_tickets"
	self.primary_key = :id

	belongs_to :ticket, :class_name => 'Helpdesk::Ticket', :foreign_key => 'ticket_id'
	belongs_to :product

	belongs_to :sla_policy, :class_name => "Helpdesk::SlaPolicy", :foreign_key => "long_tc01"
	belongs_to :parent, :class_name => 'Helpdesk::Ticket', :foreign_key => 'long_tc02'
	belongs_to_account

	attr_protected :account_id

	alias_attribute :skip_notification, :boolean_tc01
	alias_attribute :header_info, :text_tc01
	alias_attribute :st_survey_rating, :int_tc01
	alias_attribute :survey_rating_updated_at, :datetime_tc01
	alias_attribute :trashed, :boolean_tc02
	alias_attribute :sender_email, :string_tc03
	alias_attribute :access_token, :string_tc01
	alias_attribute :escalation_level, :int_tc02
	alias_attribute :sla_policy_id, :long_tc01
	alias_attribute :manual_dueby, :boolean_tc03
	alias_attribute :parent_ticket, :long_tc02
	alias_attribute :reports_hash, :text_tc02
	alias_attribute :sla_response_reminded, :boolean_tc04
	alias_attribute :sla_resolution_reminded, :boolean_tc05
	alias_attribute :dirty_attributes, :text_tc03
	alias_attribute :spam_score, :string_tc04

	alias_attribute :sentiment, :int_tc04
	alias_attribute :additional_info, :text_tc04

	# Attributes used in Freshservice
	alias_attribute :department_id, :long_tc10

	serialize :to_emails
	serialize :text_tc01, Hash
	serialize :text_tc02, Hash
	serialize :text_tc03, Hash
  serialize :text_tc04, Hash

  after_initialize :backup_change

  publishable on: [:update], exchange_model: :ticket, exchange_action: :update

  after_commit :backup_change # This neeeds to be at last

	def self.trashed_column
		:boolean_tc02
	end

	def self.survey_rating_column
		:int_tc01
	end

	def self.survey_rating_updated_at_column
		:datetime_tc01
	end

	def self.find_by_access_token(token)
		find_by_string_tc01(token)
	end

	#updating access_token for old tickets
	def update_access_token(token)  #for avoiding call back have put as separate method
		token_updated = Helpdesk::SchemaLessTicket.where(id: self.id, account_id: self.account_id, string_tc01: nil).update_all(string_tc01: token)
		if token_updated > 0
			token
		else
			#wantedly doing this to avoid taking from self as it can contain changes. So avoid reloading self
			Helpdesk::SchemaLessTicket.where(id: self.id, account_id: self.account_id).pluck(:string_tc01).first
		end
	end
	
	# Methods for new reports starts here
	def set_first_assign_bhrs(created_at_time, first_assigned, group)
		return if reports_hash.has_key?("first_assign_in_bhrs")
		first_assign_by_bhrs = nil
		BusinessCalendar.execute(self.ticket) {
			first_assign_by_bhrs = calculate_time_in_bhrs(created_at_time, first_assigned, group)
		}
  	self.reports_hash.merge!("first_assign_by_bhrs" => first_assign_by_bhrs)
	end
	
	def set_internal_agent_first_assign_bhrs(created_at_time, first_assigned, group)
		return if reports_hash.has_key?("internal_agent_first_assign_in_bhrs")
		first_assign_by_bhrs = nil
		BusinessCalendar.execute(self.ticket) {
			first_assign_by_bhrs = calculate_time_in_bhrs(created_at_time, first_assigned, group)
		}
  	self.reports_hash.merge!("internal_agent_first_assign_in_bhrs" => first_assign_by_bhrs)
	end

	def set_first_response_id(note_id)
		if reports_hash.key?('first_response_id')
      update_first_response_agent_id unless reports_hash.key?('first_response_agent_id')
    else
      self.reports_hash.merge!('first_response_id' => note_id)
      fetch_first_response_agent_id(note_id)
      self.reports_hash.merge!('first_response_group_id' => self.ticket.group_id)
      Rails.logger.info "Helpdesk::SchemaLessTicket::set_first_response_id::#{Time.zone.now.to_f} and schema_less_ticket_object :: #{reports_hash.inspect}"
      self.save
		end
	end

	def set_last_resolved_at(time)
		self.reports_hash['last_resolved_at'] = time
	end

  def update_first_response_agent_id
    first_response_agent_id = fetch_first_response_agent_id(reports_hash['first_response_id'])
    Rails.logger.info "Helpdesk::SchemaLessTicket::update_first_response_agent_id::#{Time.zone.now.to_f} and schema_less_ticket_object :: #{reports_hash.inspect}"
    self.save
    first_response_agent_id
  end

  def fetch_first_response_agent_id(note_id)
    note = self.ticket.notes.find_by_id(note_id)
    self.reports_hash.merge!('first_response_agent_id' => note.user_id) if note
    self.reports_hash['first_response_agent_id']
  end

  def set_first_assign_agent_id(agent_id)
    self.reports_hash.merge!('first_assign_agent_id' => agent_id)
  end

  def set_first_assign_group_id(group_id)
    self.reports_hash.merge!('first_assign_group_id' => group_id)
  end

  def scheduler_trace_id
    additional_info[:scheduler_trace_id]
  end

  def update_scheduler_trace_id(value)
    additional_info[:scheduler_trace_id] = value
    self.save
  end

  def reset_scheduler_trace_id
    additional_info[:scheduler_trace_id] = nil
    self.save
  end

  ['agent', 'group', 'internal_agent', 'internal_group'].each do |type|
    define_method("set_#{type}_assigned_flag") do
      reports_hash["#{type}_reassigned_flag"] = true if reports_hash["#{type}_assigned_flag"]

      reports_hash["#{type}_assigned_flag"] = true
    end

    define_method("unset_#{type}_assigned_flag") do
      reports_hash["#{type}_assigned_flag"] = nil
    end
  end

	COUNT_COLUMNS_FOR_REPORTS.each do |count_type|
		define_method("update_#{count_type}_count") do |action|
			previous_count = self.reports_hash["#{count_type}_count"]
			case action
			when "create"
				current_count  = previous_count.to_i + 1
			when "destroy"
				current_count = (previous_count.to_i == 0 ? nil : previous_count.to_i -  1)
			else
				current_count = nil
			end
			self.reports_hash["#{count_type}_count"] = current_count unless current_count.nil?
		end
	end

    def update_lifecycle_changes(event_time, group, resolved_or_closed)
        self.reports_hash ||= {}
        tkt = self.ticket
        last_updated_at = self.reports_hash["lifecycle_last_updated_at"] || ([tkt.ticket_states.status_updated_at, tkt.ticket_states.assigned_at, tkt.created_at].compact.max)
        action_time_in_bhrs = calculate_action_time_in_bhrs(last_updated_at, event_time, group)
        if action_time_in_bhrs <= 30 && !resolved_or_closed #return if action_time_in_bhrs is less than 30 seconds
            self.reports_hash["lifecycle_last_updated_at"] = event_time
            return {}
        end
        action_time_hash = {
            action_time_in_bhrs: action_time_in_bhrs,
            action_time_in_chrs: event_time - last_updated_at,
            chrs_from_tkt_creation: event_time - tkt.created_at
        }
        self.reports_hash["lifecycle_last_updated_at"] = event_time
        action_time_hash
    end

    def calculate_action_time_in_bhrs(start_time, end_time, group)
        time_in_bhrs = nil
        BusinessCalendar.execute(self.ticket) {
            time_in_bhrs = calculate_time_in_bhrs(start_time, end_time, group)
        }
        time_in_bhrs
    end

	def recalculate_note_count
		recalculated_count = Hash.new(0)
		self.ticket.notes.includes(:schema_less_note).each do |note|
			category = note.safe_send("reports_note_category")
			recalculated_count["#{category}"]+=1
	  end
	  self.reports_hash = {} unless self.reports_hash.is_a?(Hash)
	  NOTE_COUNT_METRICS.each { |metric| self.reports_hash["#{metric}_count"] = recalculated_count[metric] }
	  self.reports_hash["recalculated_count"] = true
	end

  def schema_less_ticket_was _changes = {}
  	replicate_schema_less_ticket :first, _changes
  end

  def schema_less_ticket_is _changes = {}
	replicate_schema_less_ticket :last, _changes
  end

  def replicate_schema_less_ticket index, _changes = {}
    schema_less_ticket_replica = account.schema_less_tickets.new #dup creates problems
    attributes.each do |_attribute, value| #to work around protected attributes
      schema_less_ticket_replica.safe_send("#{_attribute}=", value)
    end
    _changes ||= begin
      temp_changes = changes #calling changes builds a hash everytime
      temp_changes.present? ? temp_changes : previous_changes
    end
    _changes.each do |_attribute, change|
      if schema_less_ticket_replica.respond_to? _attribute
        schema_less_ticket_replica.safe_send("#{_attribute}=", change.safe_send(index))
      end
    end

    schema_less_ticket_replica
  end

  # count from DB(Related/Child tickets count)
  def subsidiary_tkts_count
    additional_info[:subsidiary_tkts_count]
  end

  def subsidiary_tkts_count=(value)
    additional_info[:subsidiary_tkts_count] = value
  end

  def ticket_properties_suggester_hash
    additional_info[:ticket_properties_suggester_hash]
  end

  def ticket_properties_suggester_hash=(value)
    additional_info[:ticket_properties_suggester_hash] = value
  end

  def thank_you_notes
    additional_info[:thank_you_notes]
  end

  def thank_you_notes=(value)
    additional_info[:thank_you_notes] = value
  end

  def last_customer_note_id
    additional_info[:last_customer_note_id]
  end

  def last_customer_note_id=(value)
    additional_info[:last_customer_note_id] = value
  end

  def nr_updated_at
    additional_info[:nr_updated_at]
  end

  def nr_updated_at=(value)
    additional_info[:nr_updated_at] = value
  end

  def nr_escalation_level
    additional_info[:nr_escalation_level]
  end

  def nr_escalation_level=(value)
    additional_info[:nr_escalation_level] = value
  end

  def nr_violated
    additional_info[:nr_violated]
  end

  # will be set to true if a single response by agent is violated
  def nr_violated=(value)
    additional_info[:nr_violated] = value
  end

  def tweet_type
    additional_info[:tweet_type]
  end

  def tweet_type=(value)
    additional_info[:tweet_type] = value
  end

  def fb_msg_type
    additional_info[:fb_msg_type]
  end

  def fb_msg_type=(value)
    additional_info[:fb_msg_type] = value
  end

  def override_exchange_model(_action)
    report_hash_changes = attribute_changes('text_tc02')
    changes = attribute_changes.slice(*PRESENTER_FIELDS_MAPPING.keys) || {}
    changes.keys.each do |key|
      changes[PRESENTER_FIELDS_MAPPING[key]] = changes.delete key if PRESENTER_FIELDS_MAPPING[key]
    end
    changes.merge!(report_hash_changes)
    ticket.model_changes = changes if changes.present?
  end

  def update(*)
    optimistic_rails_lock('update') do
      super
    end
  end

  def destroy(*)
    optimistic_rails_lock('destroy') do
      super
    end
  end

  private

  def email_failures
    additional_info
  end

  def attribute_changes(column_name = nil)
    attributes_was, attributes_is = column_name ? [schema_less_was["#{column_name}"], attributes["#{column_name}"]] : [schema_less_was, attributes]
    change_hash = {}
    if attributes_was.present? && attributes_is.present? && attributes_was != attributes_is
      new_hash = attributes_was.merge(attributes_is)
      new_hash.keys.each do |key|
        change_hash[key] = [attributes_was[key], attributes_is[key]] if attributes_was[key] != attributes_is[key]
      end
    end
    change_hash
  end

  def reapply_values(retry_changes)
    retry_changes.each do |db_column, db_value|
      if SERIALIZED_DB_COLUMNS.include?(db_column)
        db_value[1] = safe_send("#{db_column}").merge(db_value[1])
      end
      safe_send("#{db_column}=", db_value[1]) unless ['updated_at'].include?(db_column)
    end
  end

  def backup_change
    @schema_less_was = attributes.deep_dup
  end
end
