class Helpdesk::SlaPolicy < ActiveRecord::Base
  
  self.table_name =  "sla_policies"
  self.primary_key = :id

  serialize :escalations, Hash
  serialize :conditions, Hash
  
  validates_presence_of :name,:account
  validates_uniqueness_of :name, :scope => :account_id
  
  before_save :standardize_and_validate
  after_update :reorder_policies, if: :position_changed?

  def standardize_and_validate
    standardize_escalations(self.escalations) if escalations_changed?
    standardize_conditions if conditions_changed? 
    validate_conditions?
  end

  belongs_to_account
  
  has_many :sla_details , :class_name => "Helpdesk::SlaDetail", :foreign_key => "sla_policy_id", 
    :dependent => :destroy 
  
  attr_accessible :name,:description, :is_default, :conditions, :escalations, :active, :datatype, 
    :sla_details_attributes, :position
  
  accepts_nested_attributes_for :sla_details

  scope :rule_based, -> { where(is_default: false) }
  scope :default, ->{ where(is_default: true) }

  scope :active, ->{ where(active: true) }
  scope :inactive, ->{ where(active: false) }

  attr_accessor :datatype

  CONDITIONS_EVALUATE_ON_HASH = {
    "company_id"        => [:company_id,  :ticket],
    "group_id"          => [:group_id,    :ticket],
    "product_id"        => [:product_id,  :ticket],
    "source"            => [:source,      :ticket],
    "ticket_type"       => [:ticket_type, :ticket],
    "contact_segment"   => [:segments,    :requester],
    "company_segment"   => [:segments,    :company]
  }

  ESCALATION_LEVELS = [
    [ :level_1,   1 ], 
    [ :level_2,   2 ], 
    [ :level_3,   3 ], 
    [ :level_4,   4 ]   
  ]

  ESCALATION_LEVELS_OPTIONS = ESCALATION_LEVELS.map { |i| i[1] }
  ESCALATION_LEVELS_MAX = ESCALATION_LEVELS_OPTIONS.last
  NR_ESCALATION_LEVELS_MAX = 1

  ESCALATION_TIME = [
    [ :immediately,     0 ], 
    [ :after_half,      1800 ], 
    [ :after_one,       3600 ], 
    [ :after_two,       7200 ], 
    [ :after_four,      14400 ], 
    [ :after_eight,     28800 ], 
    [ :after_twelve,    43200 ], 
    [ :after_day,       86400 ],
    [ :after_twoday,    172800 ], 
    [ :after_threeday,  259200 ],
    [ :after_oneweek,   604800 ],
    [ :after_twoweek,   1209600 ],
    [ :after_onemonth,  2592000 ]
  ]

  PREMIUM_TIME = [ 
    [:after_five_minutes,     300], 
    [:after_ten_minutes,      600], 
    [:after_fifteen_minutes,  900] 
  ]

  ESCALATION_TYPES = [:resolution, :response, :next_response]
  REMINDER_TYPES = [:reminder_response,:reminder_resolution,:reminder_next_response]

  REMINDER_TIME = [
    [ :eight, -28800],
    [ :four,  -14400],
    [ :two,   -7200],
    [ :one,   -3600],
    [ :half,  -1800]
  ]

  REMINDER_TIME_OPTIONS = REMINDER_TIME.map { |i| [i[0], i[1]] }
  SLA_WORKER_INTERVAL = 840 #Rake task interval (14 Minutes)

  CUSTOM_USERS = [
    [:assigned_agent, -1]
  ]

  def self.premium_time
    PREMIUM_TIME.map { |i| [I18n.t("premium_sla_times.#{i[0]}"), i[1]] }
  end

  def self.esclation_time_options
    ESCALATION_TIME.map { |i| [I18n.t(i[0]), i[1]] }
  end

  def self.esclation_premium_time_options
    (self.esclation_time_options + self.premium_time).sort{|a, b|
                                                                      a[1] <=> b[1] }
  end

  def self.remainder_time_option
    REMINDER_TIME.map { |i| [I18n.t("before_#{i[0]}"), i[1]] }
  end

  API_OPTIONS = {
    :except => [:account_id]
  }
  acts_as_list :scope => 'account_id = #{account_id}'

  def matches?(ticket)
    return false if va_conditions.empty?
    va_conditions.all? { |c| c.evaluate_on_type != 'ticket' ? c.matches(ticket.safe_send(c.evaluate_on_type)) : c.matches(ticket) }
  end

#sla_resolution_reminder / sla_response_reminder

  def escalate_response_reminder ticket
    response_reminder = escalations[:reminder_response]["1"]

    if response_reminder && escalate_to_agents(ticket, response_reminder, EmailNotification::RESPONSE_SLA_REMINDER, :frDueBy)
      ticket.update_attribute(:sla_response_reminded ,true)
    end

  end

  def escalate_resolution_reminder ticket
    resolution_reminder = escalations[:reminder_resolution]["1"]

    if resolution_reminder && escalate_to_agents(ticket, resolution_reminder, EmailNotification::RESOLUTION_SLA_REMINDER, :due_by)
      ticket.update_attribute(:sla_resolution_reminded, true)
    end

  end

  def escalate_next_response_reminder ticket
    next_response_reminder = escalations[:reminder_next_response]["1"]

    if next_response_reminder && escalate_to_agents(ticket, next_response_reminder, EmailNotification::NEXT_RESPONSE_SLA_REMINDER, :nr_due_by)
      ticket.update_attribute(:nr_reminded, true)
    end
  end  

  def escalate_response_overdue(ticket)
    ticket.update_attribute(:fr_escalated, true)
    if Account.current.sla_management_enabled? && escalation_enabled?(ticket)
      response_escalation = escalations[:response].try(:[], "1")
      escalate_to_agents(ticket, response_escalation, EmailNotification::FIRST_RESPONSE_SLA_VIOLATION, :frDueBy) if response_escalation
    end
  end

  def escalate_resolution_overdue(ticket)
    params = {activity: :resolution, level: :escalation_level, max_levels: ESCALATION_LEVELS_MAX, escalated_field: :isescalated, due_by: :due_by}
    escalate_overdue(ticket, params, EmailNotification::RESOLUTION_TIME_SLA_VIOLATION)
  end

  def escalate_next_response_overdue(ticket)
    params = {activity: :next_response, level: :nr_escalation_level, max_levels: NR_ESCALATION_LEVELS_MAX, escalated_field: :nr_escalated, due_by: :nr_due_by}
    escalate_overdue(ticket, params, EmailNotification::NEXT_RESPONSE_SLA_VIOLATION)
  end

  def can_be_activated?
    !(conditions.blank? || is_default)
  end

  def self.company_policies(company)
    sla = company.account.sla_policies.rule_based.active.select do |policy| 
      policy.conditions["company_id"].present? and 
        policy.conditions["company_id"].include?(company.id)
    end
    sla.empty? ? company.account.sla_policies.default : sla 
  end

  def self.custom_users_value_by_type
    CUSTOM_USERS.inject({}) {|hash, item| hash[item[0].to_sym] = I18n.t("sla_policy.#{item[0]}.text"); hash}
  end

  def as_json(options={})
    options.merge!(API_OPTIONS)
    super options.merge(:root => 'helpdesk_sla_policy')
  end

  def self.custom_users_id_by_type
    CUSTOM_USERS.inject({}) {|hash, item| hash[item[0].to_sym] = item[1]; hash}
  end

  def self.custom_users_desc_by_type
    CUSTOM_USERS.inject({}) {|hash, item| hash[item[0].to_sym] = I18n.t("sla_policy.#{item[0]}.description"); hash}
  end
  
  def to_xml(options={})
    options.merge!(API_OPTIONS)
    super options.merge(:root => 'helpdesk_sla_policy')
  end

  def reorder_policies
    old_position = position_change[0]
    new_position = position_change[1]
    reorder_from_higher_pos = old_position > new_position
    reorder_by = reorder_from_higher_pos ? '+' : '-'
    position_upper_index = reorder_from_higher_pos ? old_position : new_position
    position_lower_index = reorder_from_higher_pos ? new_position : old_position
    account.sla_policies.where('position >= ? and position <= ? and id != ?', position_lower_index, position_upper_index, id).update_all("position = position #{reorder_by} 1")
  end

  def escalation_enabled?(ticket)
    sla_details.find_by_priority(ticket.priority).escalation_enabled?
  end

  private

    # def is_the_condition_valid? ticket, reminder_time
    #   return reminder_time[:time].seconds.since(ticket.due_by) >= ticket.created_at
    # end


    def va_conditions
      @va_conditions ||= deserialize_conditions
    end

    def deserialize_conditions
      to_return = []
      conditions.each_pair do |k, v| #each_pair
        condition_name, evaluate_on = k, :ticket
        if CONDITIONS_EVALUATE_ON_HASH.key?(k)
          condition_name = CONDITIONS_EVALUATE_ON_HASH[k][0]
          evaluate_on = CONDITIONS_EVALUATE_ON_HASH[k][1]
        end
        to_return << (Va::Condition.new({:name => condition_name, :value => v, 
                        :operator => "in", :evaluate_on => evaluate_on.to_s} , Account.current))
      end if conditions
      to_return
    end

    def escalate_to_agents(ticket, escalation, type, due_by)
      notify_time_interval = escalation[:time].seconds.since(ticket.safe_send(due_by))

      if type == EmailNotification::RESPONSE_SLA_REMINDER || EmailNotification::RESOLUTION_SLA_REMINDER || EmailNotification::NEXT_RESPONSE_SLA_REMINDER
        return false if notify_time_interval <= ticket.created_at
        notify_time_interval -= SLA_WORKER_INTERVAL
      end

      if notify_time_interval <= Time.zone.now
        assigned_agent_id = Helpdesk::SlaPolicy.custom_users_id_by_type[:assigned_agent]
        responder_id = ticket.responder_id
        internal_agent_id = ticket.internal_agent_id
        agent_ids = escalation[:agents_id].clone
        if agent_ids.include?(assigned_agent_id)
          agent_ids.delete(assigned_agent_id)
          agent_ids << responder_id if responder_id
          agent_ids << internal_agent_id if internal_agent_id && Account.current.shared_ownership_enabled?
        end
        agent_ids.uniq!
        unless agent_ids.blank?
          SlaNotifier.send_later(:group_escalation, ticket, agent_ids, type)
        end
        return true
      end
      false
    end

    def standardize_escalations(sp_escalations)
      return unless sp_escalations
      sp_escalations.each_pair do |k, v|
        next if v.blank?
        if v.has_key?(:agents_id) && v.has_key?(:time)
          v[:time] = v[:time].to_i
          v[:agents_id] = v[:agents_id].map(&:to_i) unless v[:agents_id].blank?
        else
          standardize_escalations(v)
        end
      end
    end

    def standardize_conditions
      conditions.each_pair do |k, v|
        v.blank? ? (conditions.delete k) : standardize_cond_values(k, v)
      end
    end

    def standardize_cond_values(k, v)
      return if (k == "ticket_type")
      conditions[k] = v.map(&:to_i)
    end

    def validate_conditions?
      !active || (!conditions.blank? || is_default)
    end

    def escalate_overdue(ticket, params, notification)
      ticket.update_attributes(params[:escalated_field] => true)
      return unless Account.current.sla_management_enabled? && escalation_enabled?(ticket) && escalations.key?(params[:activity])

      (((ticket.safe_send(params[:level]) || 0)+1)..params[:max_levels]).each do |escalation_level|
        escalation = escalations[params[:activity]][escalation_level.to_s]
        if !escalation
          ticket.update_attributes({ params[:level] => params[:max_levels], params[:escalated_field] => true })
          break
        end
        if escalation && escalate_to_agents(ticket, escalation, notification, params[:due_by])
          ticket.update_attribute(params[:level], escalation_level)
        else 
          break
        end
      end
      if ticket.safe_send(params[:level]) == params[:max_levels] && !ticket.safe_send(params[:escalated_field])
        ticket.update_attributes({params[:escalated_field] => true})
      end
    end

    # overriding the default method 'bottom_position_in_list' of gem 'acts_as_list'
    def bottom_position_in_list
      account.sla_policies.count
    end

end
