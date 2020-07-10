class Helpdesk::SlaDetail < ActiveRecord::Base
  self.table_name =  "sla_details" 
  self.primary_key = :id
  
  serialize :sla_target_time, HashWithIndifferentAccess
  # Temporary - skip_iso_format_conversion for updates from private API
  attr_accessor :skip_iso_format_conversion

  belongs_to_account
  belongs_to :sla_policy, :class_name => "Helpdesk::SlaPolicy"

  before_validation :populate_sla_target_time, unless: :skip_iso_format_conversion
  validate :valid_sla_target_time?, if: :sla_policy_revamp_enabled?
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
  SLA_OPTIONS_BY_TOKEN = Hash[*SLA_OPTIONS.map { |i| [i[0], i[2]] }.flatten]

  SLA_TIME = [
    [ :business, false ], 
    [ :calendar, true ],        
  ]

  SLA_TIME_PERIODS = [
    [:period,      'P'],
    [:days,        'D'],
    [:time,        'T'], 
    [:hours,       'H'],
    [:minutes,     'M']
  ]

  SLA_TARGETS = [
    ['first_response_time', 'response_time'],
    ['every_response_time', 'next_response_time'],
    ['resolution_due_time', 'resolution_time']
  ]

  SLA_TARGETS_COLUMN_MAPPINGS = Hash[*SLA_TARGETS.map { |i| [i[0], i[1]] }.flatten]
  # SLA_TIME_OPTIONS = SLA_TIME.map { |i| [i[1], i[2]] }
  SLA_TARGETS = [
    ['first_response_time', 'response_time'],
    ['every_response_time', 'next_response_time'],
    ['resolution_due_time', 'resolution_time']
  ].freeze
  SLA_TARGETS_COLUMN_MAPPINGS = Hash[*SLA_TARGETS.map { |i| [i[0], i[1]] }.flatten]
  SLA_TIME_BY_KEY = Hash[*SLA_TIME.map { |i| [i[1], i[0]] }.flatten]
  SLA_TIME_BY_TOKEN = Hash[*SLA_TIME.map { |i| [i[0], i[1]] }.flatten]
  SLA_TIME_PERIOD_SUFFIX = Hash[*SLA_TIME_PERIODS.map { |i| [i[0], i[1]] }.flatten]

  SLA_TARGET_TIME_REGEX = /^P(?=.)(?<day>\d+D)?(T(?=\d+[HM])(?<hour>\d+H)?(?<minute>\d+M)?)?$/.freeze

  default_scope ->{ order("priority DESC") }

  def calculate_due_by(created_time, time_zone_now, total_time_worked, calendar)
    target_time = sla_policy_revamp_enabled? ? sla_target_time[:resolution_due_time] : resolution_time
    Rails.logger.debug "SLA :::: Account id #{account_id} :: Calculating due by :: created_time :: #{created_time} resolution_time :: #{target_time} total_time_worked :: #{total_time_worked} calendar :: #{calendar.id} - #{calendar.name} override_bhrs :: #{override_bhrs}"
    calculate_due(created_time, time_zone_now, target_time, total_time_worked, calendar)
  end

  def calculate_frDue_by(created_time, time_zone_now, total_time_worked, calendar)
    target_time = sla_policy_revamp_enabled? ? sla_target_time[:first_response_time] : response_time.seconds
    Rails.logger.debug "SLA :::: Account id #{account_id} :: Calculating fr due by :: created_time :: #{created_time} response_time :: #{target_time} total_time_worked :: #{total_time_worked} calendar :: #{calendar.id} - #{calendar.name} override_bhrs :: #{override_bhrs}"
    calculate_due(created_time, time_zone_now, target_time, total_time_worked, calendar)
  end

  def calculate_nr_dueBy(created_time, time_zone_now, total_time_worked, calendar)
    target_time = sla_policy_revamp_enabled? ? sla_target_time[:every_response_time].presence : next_response_time.try(:seconds)
    unless target_time.nil?
      Rails.logger.debug "SLA :::: Account id #{account_id} :: Calculating nr due by :: created_time :: #{created_time} next response_time :: #{target_time} total_time_worked :: #{total_time_worked} calendar :: #{calendar.id} - #{calendar.name} override_bhrs :: #{override_bhrs}"
      calculate_due(created_time, time_zone_now, target_time, total_time_worked, calendar)
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

  SLA_TARGETS_COLUMN_MAPPINGS.keys.each do |sla|
    define_method "#{sla}" do
      sla_target_time[sla.to_sym]
    end
    define_method "#{sla}=" do |value|
      sla_target_time[sla.to_sym] = value
    end
  end
  
  # Adding this temporary method to populate the new serialized column --> 'sla_target_time'
  # This method converts response_time, resolution_time, next_response_time which are in seconds to ISO 8601 format
  
  def populate_sla_target_time
    SLA_TARGETS_COLUMN_MAPPINGS.each do |new_column, old_column|
      target_time = self[old_column.to_sym]
      self.sla_target_time[new_column.to_sym] = target_time.nil? ? nil : convert_to_iso_format(target_time)
    end
  end

  def convert_to_iso_format(seconds)
    formatted_time = ''
    SLA_TIME_PERIOD_SUFFIX.each do |time, suffix|
      break if seconds < 60
      unless SLA_OPTIONS_BY_TOKEN.key?(time)
        formatted_time += suffix
        next
      end
      time_in_seconds = SLA_OPTIONS_BY_TOKEN[time]
      seconds, remainder_seconds = seconds.divmod(time_in_seconds)
      if remainder_seconds == 1
        seconds *= time_in_seconds
        next
      elsif remainder_seconds == 0
        formatted_time.concat(seconds.to_s).concat(suffix)
        seconds = remainder_seconds
      else
        seconds = (seconds * time_in_seconds) + remainder_seconds
      end
    end
    formatted_time
  end

  def target_time_in_seconds(formatted_time)
    duration_match_data = formatted_time.match(SLA_TARGET_TIME_REGEX)
    return nil if duration_match_data.nil?

    duration_names = duration_match_data.names # [day, hour, minute]
    duration_values = duration_match_data.captures
    total_time = 0
    duration_names.each_with_index do |d_name, index|
      total_time += duration_values[index].chop.to_i.safe_send(d_name).seconds if duration_values[index].present?
    end
    total_time
  end

  private

    def business_time(sla_time, from_time, calendar)
      fact = sla_time.div(ONE_DAY_IN_SECONDS)
      
      if sla_time.modulo(ONE_DAY_IN_SECONDS).zero?
        business_days = fact.business_days
        business_days.business_calendar_config = calendar
        business_days.after(from_time)
      else
        business_minutes = convert_to_business_minutes(sla_time, calendar)
        business_minutes.after(from_time)
      end
    end
    
    def business_time_for_new_format(formatted_time, from_time, calendar)
      duration_match_data = formatted_time.match(SLA_TARGET_TIME_REGEX)
      return nil if duration_match_data.nil?

      due_time = from_time
      remaining_time = formatted_time.dup
      days_duration = duration_match_data[:day] # eg: '1D', '5D'
      if days_duration.present?
        remaining_time.slice!(days_duration)
        business_days = days_duration.chop.to_i.business_days
        due_time = business_days.after(due_time)
      end
      return due_time if remaining_time == 'P' # return if only days were set eg: 'P30D'
      remaining_seconds = target_time_in_seconds(remaining_time)
      business_minutes = convert_to_business_minutes(remaining_seconds, calendar)
      business_minutes.after(due_time)
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

    # Method to be used for converting new format to seconds - temporary
    # def populate_sla_time_seconds
    #   SLA_TARGETS_COLUMN_MAPPINGS.each do |new_column, old_column|
    #     self[old_column.to_sym] = sla_target_time[new_column.to_sym].blank? ? nil : target_time_in_seconds(sla_target_time[new_column.to_sym])
    #   end
    # end

    def valid_sla_target_time?
      SLA_TARGETS_COLUMN_MAPPINGS.each do |new_column, old_column|
        target_time = self[old_column.to_sym]
        if target_time.nil?
          # allow nil if next response time is not set
          next if old_column == 'next_response_time' && sla_target_time[new_column].blank?

          errors.add(:base, I18n.t('sla_policy.error.invalid_sla_target_time_format'))
        elsif target_time > 1.year
          errors.add(:base, I18n.t('sla_policy.error.target_time_greater_than_1_year'))
        elsif target_time < 15.minutes
          errors.add(:base, I18n.t('sla_policy.error.target_time_less_than_15_minutes'))
        end
      end
    end

    def calculate_due(created_time, time_zone_now, target_time, total_time_worked, calendar)
      if sla_policy_revamp_enabled?
        return calculate_due_for_new_format(created_time, time_zone_now, target_time, total_time_worked, calendar)
      end
      resolution_time_in_seconds = target_time
      if override_bhrs
       total_time_worked > resolution_time_in_seconds ? (created_time + resolution_time_in_seconds) : (time_zone_now + (resolution_time_in_seconds - total_time_worked))
      else
        business_seconds = convert_to_business_seconds(resolution_time_in_seconds, calendar, time_zone_now)
        if total_time_worked > business_seconds 
          business_time(resolution_time_in_seconds, created_time, calendar)
        else
          due_date = business_time(resolution_time_in_seconds, time_zone_now, calendar)
          if total_time_worked > 60 # 1 minute
            due_date = convert_to_business_minutes(total_time_worked, calendar).before(due_date)
          end
          due_date
        end
      end
    end

    # Temporary method - will be cleaned up after deprecating existing SLA API
    def calculate_due_for_new_format(created_time, time_zone_now, target_time, total_time_worked, calendar)
      if override_bhrs
        target_time_in_seconds = target_time_in_seconds(target_time)
        return nil if target_time_in_seconds.nil?

        total_time_worked > target_time_in_seconds ? (created_time + target_time_in_seconds) : (time_zone_now + (target_time_in_seconds - total_time_worked))
      else
        business_seconds = convert_new_format_to_business_seconds(target_time, time_zone_now)
        if total_time_worked > business_seconds
          business_time_for_new_format(target_time, created_time, calendar)
        else
          due_date = business_time_for_new_format(target_time, time_zone_now, calendar)
          # advance due time by the total_time_worked
          if due_date && total_time_worked > 60
            due_date = convert_to_business_minutes(total_time_worked, calendar).before(due_date)
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

    # Temporary method - will be cleaned up after deprecating existing SLA API
    def convert_new_format_to_business_seconds(formatted_time, current_time)
      duration_match_data = formatted_time.match(SLA_TARGET_TIME_REGEX)
      return 0 if duration_match_data.nil?

      days_in_business_seconds = 0
      remaining_time = formatted_time.dup
      days_duration = duration_match_data[:day] # eg: '1D', '5D'
      if days_duration.present?
        remaining_time.slice!(days_duration)
        business_days = days_duration.chop.to_i.business_days # no. of biz days
        days_in_business_seconds += current_time.business_time_until(business_days.after(current_time)).ceil
      end
      return days_in_business_seconds if remaining_time == 'P' # return if only days were set eg: 'P30D'
      days_in_business_seconds + target_time_in_seconds(remaining_time)
    end

    def convert_to_business_minutes(time_in_seconds, calendar)
      business_minutes = time_in_seconds.div(60).business_minute
      business_minutes.business_calendar_config = calendar
      business_minutes
    end

    def sla_policy_revamp_enabled?
      account.sla_policy_revamp_enabled?
    end
end
