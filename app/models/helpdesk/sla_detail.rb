class Helpdesk::SlaDetail < ActiveRecord::Base
  self.table_name =  "sla_details" 
  self.primary_key = :id
  
  belongs_to_account
  belongs_to :sla_policy, :class_name => "Helpdesk::SlaPolicy"
  before_create :set_account_id

  before_save :check_sla_time

  RESPONSETIME = [
    [ :half,      1800 ], 
    [ :one,       3600 ], 
    [ :two,       7200 ], 
    [ :four,      14400 ], 
    [ :eight,     28800 ], 
    [ :twelve,    43200 ], 
    [ :day,       86400 ],
    [ :twoday,    172800 ], 
    [ :threeday,  259200 ]
  ]

  ONE_DAY_IN_SECONDS = 86400
  
  RESPONSETIME_KEYS_BY_TOKEN = Hash[*RESPONSETIME.map { |i| [i[0], i[2]] }.flatten]

  RESOLUTIONTIME = [
    [ :half,        1800 ], 
    [ :one,         3600 ], 
    [ :two,          7200 ], 
    [ :four,        14400 ], 
    [ :eight,       28800 ], 
    [ :twelve,      43200 ], 
    [ :day,         86400 ],
    [ :twoday,      172800 ], 
    [ :threeday,    259200 ],
    [ :oneweek,     604800 ],
    [ :twoweek,     1209600 ],
    [ :onemonth,    2592000 ],
    [ :twomonth,    5184000 ],
    [ :threemonth,  7776000 ],
    [ :sixmonth,    15811200 ],
    [ :oneyear,     31536000 ]
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

  RESOLUTIONTIME_KEYS_BY_TOKEN = Hash[*RESOLUTIONTIME.map { |i| [i[0], i[2]] }.flatten]

  PREMIUM_TIME_OPTIONS = [ 
    [:five_minutes,     300], 
    [:ten_minutes,      600], 
    [:fifteen_minutes,  900] 
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
    [ :business, false ], 
    [ :calendar, true ],        
  ]

  # SLA_TIME_OPTIONS = SLA_TIME.map { |i| [i[1], i[2]] }
  SLA_TIME_BY_KEY = Hash[*SLA_TIME.map { |i| [i[1], i[0]] }.flatten]
  SLA_TIME_BY_TOKEN = Hash[*SLA_TIME.map { |i| [i[0], i[1]] }.flatten]

  default_scope :order => "priority DESC"

  def calculate_due_by(created_time, time_zone_now, total_time_worked, calendar)
    Rails.logger.debug "SLA :::: Account id #{self.account_id} :: Calculating due by :: created_time :: #{created_time} resolution_time :: #{resolution_time} total_time_worked :: #{total_time_worked} calendar :: #{calendar.id} - #{calendar.name} override_bhrs :: #{override_bhrs}"
    calculate_due(created_time, time_zone_now, resolution_time, total_time_worked, calendar)
  end

  def calculate_frDue_by(created_time, time_zone_now, total_time_worked, calendar)
    Rails.logger.debug "SLA :::: Account id #{self.account_id} :: Calculating fr due by :: created_time :: #{created_time} response_time :: #{response_time.seconds} total_time_worked :: #{total_time_worked} calendar :: #{calendar.id} - #{calendar.name} override_bhrs :: #{override_bhrs}"
    calculate_due(created_time, time_zone_now, response_time.seconds, total_time_worked, calendar)
  end

  def calculate_nr_dueBy(created_time, time_zone_now, total_time_worked, calendar)
    unless next_response_time.nil?
      Rails.logger.debug "SLA :::: Account id #{self.account_id} :: Calculating nr due by :: created_time :: #{created_time} next response_time :: #{next_response_time.seconds} total_time_worked :: #{total_time_worked} calendar :: #{calendar.id} - #{calendar.name} override_bhrs :: #{override_bhrs}"
      calculate_due(created_time, time_zone_now, next_response_time.seconds, total_time_worked, calendar)
    end
  end

  def self.sla_options
    SLA_OPTIONS.map { |i| [I18n.t(i[1]), i[2]] }
  end

  def self.sla_time_options
    SLA_TIME.map { |i| [I18n.t("sla_policy.#{i[0]}"), i[1]] }
  end

  def self.response_time_options
    RESPONSETIME.map { |i| [I18n.t(i[0]), i[1]] }
  end

  def self.response_time_name_by_key
    Hash[*RESPONSETIME.map { |i| [i[1], I18n.t(i[0])] }.flatten]
  end

  def self.resolution_time_option
    RESOLUTIONTIME.map { |i| [I18n.t(i[0]), i[1]] }
  end

  def self.resolution_time_name_by_key
    Hash[*RESOLUTIONTIME.map { |i| [i[1], I18n.t(i[0])] }.flatten]
  end

  def self.premium_time_options
    @premiumtime ||= PREMIUM_TIME_OPTIONS.map { |i| [I18n.t("premium_sla_times.#{i[0]}"), i[1]] }
  end

  private

    def business_time(sla_time, from_time, calendar)
      fact = sla_time.div(ONE_DAY_IN_SECONDS)
      
      if sla_time.modulo(ONE_DAY_IN_SECONDS).zero?
        business_days = fact.business_days
        business_days.business_calendar_config = calendar
        business_days.after(from_time)
      else
        business_minute = sla_time.div(60).business_minute
        business_minute.business_calendar_config = calendar
        business_minute.after(from_time)
      end
    end
    
    def set_account_id
      self.account_id = sla_policy.account_id
    end

    def check_sla_time
      self.response_time = response_time >= SECONDS_RANGE[:min_seconds] ? (response_time <= SECONDS_RANGE[:max_seconds_by_days] ? response_time : SECONDS_RANGE[:max_seconds_by_months]) : SECONDS_RANGE[:min_seconds]
      self.resolution_time = resolution_time >= SECONDS_RANGE[:min_seconds] ? (resolution_time <= SECONDS_RANGE[:max_seconds_by_days] ? resolution_time : SECONDS_RANGE[:max_seconds_by_months]) : SECONDS_RANGE[:min_seconds]
      if next_response_time.nil?
        self.next_response_time = nil
      else
        self.next_response_time = next_response_time >= SECONDS_RANGE[:min_seconds] ? (next_response_time <= SECONDS_RANGE[:max_seconds_by_days] ? next_response_time : SECONDS_RANGE[:max_seconds_by_months]) : SECONDS_RANGE[:min_seconds]
      end
    end

    def calculate_due(created_time, time_zone_now, resolution_time_in_seconds, total_time_worked, calendar)
      if override_bhrs
       total_time_worked > resolution_time_in_seconds ? (created_time + resolution_time_in_seconds) : (time_zone_now + (resolution_time_in_seconds - total_time_worked))
      else
        business_seconds = convert_to_business_seconds(resolution_time_in_seconds, calendar, time_zone_now)
        if total_time_worked > business_seconds 
          business_time(resolution_time_in_seconds, created_time, calendar)
        else
          due_date = business_time(resolution_time_in_seconds, time_zone_now, calendar)
          if total_time_worked > 60 # 1 minute
            business_minute = total_time_worked.div(60).business_minute
            business_minute.business_calendar_config = calendar
            due_date = business_minute.before(due_date)
          end
          due_date
        end
      end
    end

    def convert_to_business_seconds(resolution_time_in_seconds, calendar, current_time)
      if resolution_time_in_seconds.modulo(ONE_DAY_IN_SECONDS).zero?
        fact = resolution_time_in_seconds.div(ONE_DAY_IN_SECONDS)
        business_days = fact.business_days
        business_days.business_calendar_config = calendar
        business_time_from_now = business_days.after(current_time)
        resolution_time_in_seconds = (current_time.business_time_until(business_time_from_now)).ceil
      end
      resolution_time_in_seconds
    end
    
end
