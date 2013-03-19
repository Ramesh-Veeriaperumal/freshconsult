class Helpdesk::SlaPolicy < ActiveRecord::Base
  
  set_table_name "sla_policies"

  serialize :escalations, Hash
  serialize :conditions, Hash
  
  validates_presence_of :name,:account
  validates_uniqueness_of :name, :scope => :account_id

  def before_save 
    standardize_esccalations(self.escalations) if escalations_changed?
    standardize_conditions if conditions_changed? 
    validate_conditions?
  end

  belongs_to :account
  
  has_many :sla_details , :class_name => "Helpdesk::SlaDetail", :foreign_key => "sla_policy_id", 
    :dependent => :destroy 

  has_many :customers , :foreign_key => "sla_policy_id" 
  
  attr_accessible :name,:description, :is_default, :conditions, :escalations, :active
  
  accepts_nested_attributes_for :sla_details

  named_scope :rule_based, :conditions => { :is_default => false }
  named_scope :default, :conditions => { :is_default => true }

  named_scope :active, :conditions => {:active => true }
  named_scope :inactive, :conditions => {:active => false }

  default_scope :order => "is_default, position"

  ESCALATION_LEVELS = [
    [ :level_1,   1 ], 
    [ :level_2,   2 ], 
    [ :level_3,   3 ], 
    [ :level_4,   4 ]   
  ]

  ESCALATION_LEVELS_OPTIONS = ESCALATION_LEVELS.map { |i| i[1] }
  ESCALATION_LEVELS_MAX = ESCALATION_LEVELS_OPTIONS.last

  ESCALATION_TIME = [
    [ :immediately,    I18n.t('immediately'),  0 ], 
    [ :half,    I18n.t('after_half'),  1800 ], 
    [ :one,      I18n.t('after_one'),      3600 ], 
    [ :two,      I18n.t('after_two'),      7200 ], 
    [ :four,     I18n.t('after_four'),     14400 ], 
    [ :eight,    I18n.t('after_eight'),     28800 ], 
    [ :twelve,   I18n.t('after_twelve'),    43200 ], 
    [ :day,      I18n.t('after_day'),      86400 ],
    [ :twoday,   I18n.t('after_twoday'),     172800 ], 
    [ :threeday, I18n.t('after_threeday'),     259200 ],
    [ :oneweek, I18n.t('after_oneweek'),     604800 ],
    [ :twoweek, I18n.t('after_twoweek'),     1209600 ],
    [ :onemonth, I18n.t('after_onemonth'),   2592000 ]
  ]

  ESCALATION_TIME_OPTIONS = ESCALATION_TIME.map { |i| [i[1], i[2]] }

  PREMIUM_TIME = [ 
    [I18n.t('premium_sla_times.after_five_minutes'),300], 
    [I18n.t('premium_sla_times.after_ten_minutes'),600], 
    [I18n.t('premium_sla_times.after_fifteen_minutes'), 900] 
  ]
  ESCALATION_PREMIUM_TIME_OPTIONS = (ESCALATION_TIME_OPTIONS + PREMIUM_TIME).sort{|a, b|
                                                                      a[1] <=> b[1] } 

  ESCALATION_TYPES = [:resolution, :response]

  acts_as_list

  def scope_condition
    "account_id = #{account_id}"
  end
  
  def matches?(evaluate_on)
    return false if va_conditions.empty?
    va_conditions.all? { |c| c.matches(evaluate_on) }
  end

  def escalate_resolution_overdue(ticket)
    unless escalation_enabled?(ticket) && escalations.key?(:resolution)
      ticket.update_attributes({:escalation_level => ESCALATION_LEVELS_MAX, :isescalated => true})
      return
    end

    (((ticket.escalation_level || 0)+1)..ESCALATION_LEVELS_MAX).each do |escalation_level|

      resolution_escalation = escalations[:resolution][escalation_level.to_s]
      if !resolution_escalation
        ticket.update_attributes({:escalation_level => ESCALATION_LEVELS_MAX, :isescalated => true})
        break
      end

      if resolution_escalation && escalate_to_agents(ticket, resolution_escalation, 
                                      EmailNotification::RESOLUTION_TIME_SLA_VIOLATION, :due_by)
        ticket.update_attribute(:escalation_level, escalation_level)
      else 
        break
      end
    end

    if ticket.escalation_level == ESCALATION_LEVELS_MAX && !ticket.isescalated
      ticket.update_attributes({:isescalated => true})
    end

  end

  def escalate_response_overdue(ticket)
    unless escalation_enabled?(ticket) && escalations.key?(:response)
      ticket.update_attribute(:fr_escalated, true)
      return
    end

    response_escalation = escalations[:response]["1"]
    if !response_escalation || 
        escalate_to_agents(ticket, response_escalation, 
          EmailNotification::FIRST_RESPONSE_SLA_VIOLATION, :frDueBy)
      ticket.update_attribute(:fr_escalated , true)
    end
  end

  def can_be_activated?
    !(conditions.blank? || is_default)
  end

  private

    def va_conditions
      @va_conditions ||= deserialize_conditions
    end

    def deserialize_conditions
      to_return = []
      conditions.each_pair do |k, v| #each_pair
        to_return << (Va::Condition.new({:name => k, :value => v, 
                        :operator => "in"} , account))
      end if conditions
      to_return
    end

    def escalation_enabled?(ticket)
      sla_details.find_by_priority(ticket.priority).escalation_enabled?
    end

    def escalate_to_agents(ticket, escalation, type, due_by)
      if escalation[:time].seconds.since(ticket.send(due_by)) <= Time.zone.now
        unless escalation[:agents_id].blank? ||
        (agents = account.users.technicians.visible.find(:all, :conditions => ["id in (?)", escalation[:agents_id]])).blank?
          SlaNotifier.send_email(ticket, agents, type)
        end
        return true
      end
      false
    end

    def standardize_esccalations(sp_escalations)
      return unless sp_escalations
      sp_escalations.each_pair do |k, v|
        next if v.blank?
        if v.has_key?(:agents_id) && v.has_key?(:time)
          v[:time] = v[:time].to_i
          v[:agents_id] = v[:agents_id].map(&:to_i) unless v[:agents_id].blank?
        else
          standardize_esccalations(v)
        end
      end
    end

    def standardize_conditions
      conditions.each_pair do |k, v|
        v.blank? ? (conditions.delete k) : (conditions[k] = v.map(&:to_i))
      end
    end

    def validate_conditions?
      !active || (!conditions.blank? || is_default)
    end

end
