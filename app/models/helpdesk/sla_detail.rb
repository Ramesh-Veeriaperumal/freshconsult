class Helpdesk::SlaDetail < ActiveRecord::Base
  self.table_name =  "sla_details" 
  self.primary_key = :id
  
  belongs_to_account
  belongs_to :sla_policy, :class_name => "Helpdesk::SlaPolicy"
  before_create :set_account_id

  before_save :check_sla_time

  RESPONSETIME = [
    [ :half,    I18n.t('half'),  1800 ], 
    [ :one,      I18n.t('one'),      3600 ], 
    [ :two,      I18n.t('two'),      7200 ], 
    [ :four,     I18n.t('four'),     14400 ], 
    [ :eight,    I18n.t('eight'),     28800 ], 
    [ :twelve,   I18n.t('twelve'),    43200 ], 
    [ :day,      I18n.t('day'),      86400 ],
    [ :twoday,   I18n.t('twoday'),     172800 ], 
    [ :threeday, I18n.t('threeday'),     259200 ]
  ]

  ONE_DAY_IN_SECONDS = 86400

  RESPONSETIME_OPTIONS = RESPONSETIME.map { |i| [i[1], i[2]] }
  RESPONSETIME_NAMES_BY_KEY = Hash[*RESPONSETIME.map { |i| [i[2], i[1]] }.flatten]
  RESPONSETIME_KEYS_BY_TOKEN = Hash[*RESPONSETIME.map { |i| [i[0], i[2]] }.flatten]

  RESOLUTIONTIME = [
    [ :half,    I18n.t('half'),  1800 ], 
    [ :one,      I18n.t('one'),      3600 ], 
    [ :two,      I18n.t('two'),      7200 ], 
    [ :four,     I18n.t('four'),     14400 ], 
    [ :eight,    I18n.t('eight'),     28800 ], 
    [ :twelve,   I18n.t('twelve'),    43200 ], 
    [ :day,      I18n.t('day'),      86400 ],
    [ :twoday,   I18n.t('twoday'),     172800 ], 
    [ :threeday, I18n.t('threeday'),     259200 ],
    [ :oneweek, I18n.t('oneweek'),     604800 ],
    [ :twoweek, I18n.t('twoweek'),     1209600 ],
    [ :onemonth, I18n.t('onemonth'),   2592000 ],
    [ :twomonth, I18n.t('twomonth'),   5184000 ],
    [ :threemonth, I18n.t('threemonth'),   7776000 ],
    [ :sixmonth, I18n.t('sixmonth'),   15811200 ],
    [ :oneyear, I18n.t('oneyear'),   31536000 ]
  ]

  SLA_OPTIONS = [
    [:minutes, 'sla.minutes', 60],
    [:hours, 'sla.hours', 3600],
    [:days, 'sla.days', 86400],
    [:months, 'sla.months', 2592000]
  ]

  SECONDS = [
    [:min_seconds, 900],
    [:max_seconds_by_days, 31536000],
    [:max_seconds_by_months, 31104000]
  ]

  SECONDS_RANGE = Hash[*SECONDS.map { |i| [i[0], i[1]] }.flatten]

  RESOLUTIONTIME_OPTIONS = RESOLUTIONTIME.map { |i| [i[1], i[2]] }
  RESOLUTIONTIME_NAMES_BY_KEY = Hash[*RESOLUTIONTIME.map { |i| [i[2], i[1]] }.flatten]
  RESOLUTIONTIME_KEYS_BY_TOKEN = Hash[*RESOLUTIONTIME.map { |i| [i[0], i[2]] }.flatten]

  PREMIUM_TIME_OPTIONS = [ 
    [I18n.t('premium_sla_times.five_minutes'),300], 
    [I18n.t('premium_sla_times.ten_minutes'),600], 
    [I18n.t('premium_sla_times.fifteen_minutes'), 900] 
  ]

  PRIORITIES = [
    [ 'low',       "Low",         1 ], 
    [ 'medium',    "Medium",      2 ], 
    [ 'high',      "High",        3 ], 
    [ 'urgent',    "Urgent",      4 ]
  ]

  PRIORITY_OPTIONS = PRIORITIES.map { |i| [i[1], i[2]] }
  PRIORITY_NAMES_BY_KEY = Hash[*PRIORITIES.map { |i| [i[2], i[0]] }.flatten]
  PRIORITY_KEYS_BY_TOKEN = Hash[*PRIORITIES.map { |i| [i[0], i[2]] }.flatten]

  SLA_TIME = [
    [ :business,       I18n.t('admin.home.index.business-hours'),      false ], 
    [ :calendar,    I18n.t('sla_policy.calendar_time'),      true ],        
  ]

  SLA_TIME_OPTIONS = SLA_TIME.map { |i| [i[1], i[2]] }
  SLA_TIME_BY_KEY = Hash[*SLA_TIME.map { |i| [i[2], i[0]] }.flatten]
  SLA_TIME_BY_TOKEN = Hash[*SLA_TIME.map { |i| [i[0], i[2]] }.flatten]

  default_scope :order => "priority DESC"

  def calculate_due_by_time_on_priority_change(created_time, calendar)
    override_bhrs ? (created_time + resolution_time.seconds) : business_time(resolution_time, created_time, calendar)
  end

  def calculate_frDue_by_time_on_priority_change(created_time, calendar)
    override_bhrs ? (created_time + response_time.seconds) : business_time(response_time, created_time, calendar)
  end

  def calculate_due_by_time_on_status_change(ticket,calendar)
    override_bhrs ? on_status_change_override_bhrs(ticket, ticket.due_by) : 
      on_status_change_bhrs(ticket, ticket.due_by,calendar)
  end

  def calculate_frDue_by_time_on_status_change(ticket,calendar)
    override_bhrs ? on_status_change_override_bhrs(ticket, ticket.frDueBy) :
      on_status_change_bhrs(ticket, ticket.frDueBy,calendar)
  end

  def self.sla_options
    SLA_OPTIONS.map { |i| [I18n.t(i[1]), i[2]] }
  end

  private

    def business_time(sla_time, created_time, calendar)
      fact = sla_time.div(ONE_DAY_IN_SECONDS)
      
      if sla_time.modulo(ONE_DAY_IN_SECONDS).zero?
        business_days = fact.business_days
        business_days.business_calendar_config = calendar
        business_days.after(created_time)
      else
        business_minute = sla_time.div(60).business_minute
        business_minute.business_calendar_config = calendar
        business_minute.after(created_time)
      end
    end

    def on_status_change_override_bhrs(ticket, due_by_type)
      elapsed_time = Time.zone.now - ticket.ticket_states.sla_timer_stopped_at  
      if due_by_type > ticket.ticket_states.sla_timer_stopped_at
        due_by_type + elapsed_time 
      else
        due_by_type
      end
    end

    def on_status_change_bhrs(ticket, due_by_type, calendar)
      sla_timer = ticket.ticket_states.sla_timer_stopped_at
      bhrs_during_elapsed_time =  sla_timer.business_time_until(
        Time.zone.now,calendar)
      if due_by_type > sla_timer
        business_minute = bhrs_during_elapsed_time.div(60).business_minute
        business_minute.business_calendar_config = calendar
        business_minute.after(due_by_type) 
      else
        due_by_type
      end
    end 

    def set_account_id
      self.account_id = sla_policy.account_id
    end

    def check_sla_time
      self.response_time = response_time >= SECONDS_RANGE[:min_seconds] ? (response_time <= SECONDS_RANGE[:max_seconds_by_days] ? response_time : SECONDS_RANGE[:max_seconds_by_months]) : SECONDS_RANGE[:min_seconds]
      self.resolution_time = resolution_time >= SECONDS_RANGE[:min_seconds] ? (resolution_time <= SECONDS_RANGE[:max_seconds_by_days] ? resolution_time : SECONDS_RANGE[:max_seconds_by_months]) : SECONDS_RANGE[:min_seconds]
    end
    
end
