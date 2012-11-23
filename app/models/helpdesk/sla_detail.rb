class Helpdesk::SlaDetail < ActiveRecord::Base
  set_table_name "helpdesk_sla_details" 

  belongs_to :sla_policy, :class_name => "Helpdesk::SlaPolicy"
  has_one :account , :through => :sla_policy 
    
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
    [ :onemonth, I18n.t('onemonth'),   2592000 ]
  ]

  RESOLUTIONTIME_OPTIONS = RESOLUTIONTIME.map { |i| [i[1], i[2]] }
  RESOLUTIONTIME_NAMES_BY_KEY = Hash[*RESOLUTIONTIME.map { |i| [i[2], i[1]] }.flatten]
  RESOLUTIONTIME_KEYS_BY_TOKEN = Hash[*RESOLUTIONTIME.map { |i| [i[0], i[2]] }.flatten]

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

  def calculate_due_by_time(ticket, created_time)
    override_bhrs ? (created_time + resolution_time.seconds) : business_time(resolution_time, created_time)
  end

  def calculate_frDue_by_time(ticket, created_time)
    override_bhrs ? (created_time + response_time.seconds) : business_time(response_time, created_time)
  end

  def calculate_due_by_time_on_status_change(ticket)
    override_bhrs ? on_status_change_override_bhrs(ticket, ticket.due_by) : 
      on_status_change_bhrs(ticket, ticket.due_by)
  end

  def calculate_frDue_by_time_on_status_change(ticket)
    override_bhrs ? on_status_change_override_bhrs(ticket,ticket.frDueBy) :
      on_status_change_bhrs(ticket, ticket.frDueBy)
  end

  private

    def business_time(sla_time, created_time)
      fact = sla_time.div(86400)
      (fact > 0) ?  fact.business_days.after(created_time) : sla_time.div(60).business_minute.after(created_time)
    end

    def on_status_change_override_bhrs(ticket, ticket_attr)
      elapsed_time = Time.zone.now - ticket.ticket_states.sla_timer_stopped_at  
      ticket_attr + elapsed_time if Ticket.due_by > ticket.ticket_states.sla_timer_stopped_at
    end

    def on_status_change_bhrs(ticket, ticket_attr)
      bhrs_during_elapsed_time =  Time.parse(ticket.ticket_states.sla_timer_stopped_at.to_s).business_time_until(
        Time.zone.now)
      bhrs_during_elapsed_time.div(60).business_minute.after(ticket_attr) if ticket_attr > 
      ticket.ticket_states.sla_timer_stopped_at
    end 
end
