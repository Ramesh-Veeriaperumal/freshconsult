module ApiBusinessCalendarConstants
  ALL_TIME_AVAILABLE = '24_7_availability'.freeze
  CUSTOM_AVAILABLE = 'custom'.freeze
  TICKET_CHANNEL = 'ticket'.freeze
  PERMITTED_PARAMS = %i[id name description time_zone channel_business_hours holidays].freeze
  CREATE_FIELDS = (PERMITTED_PARAMS - %i[id]).freeze
  HOLIDAYS_PERMITTED_PARAMS = %w[date name].freeze
  VALID_CHANNEL_PARAMS = %w[ticket].freeze
  TIME_SLOTS_PARAMS = %w[start_time end_time].freeze
  VALID_MINUTES_DATA = [0, 30, 59].freeze
  CHANNEL_BUSINESS_HOURS_PARAMS = %w[channel business_hours_type business_hours].freeze
  BUSINESS_HOURS_TYPE_ALLOWED = %w[24_7_availability custom].freeze
  TIMEZONES = ActiveSupport::TimeZone.all.map(&:name).freeze

  CUSTOM_BUSINESS_HOURS_PARAMS = %w[day time_slots].freeze
  WORKING_HOURS_INFO = [:beginning_of_workday, :end_of_workday].freeze
  WEEKDAY_HUMAN_LIST = %w[sunday monday tuesday wednesday thursday friday saturday].freeze
  CREATE_PARAMS = {
    name: :name,
    time_zone: :time_zone,
    description: :description
  }.freeze

  VALID_MONTH_NAME_DAY_LIST = {
    Jan: 31, Feb: 29, Mar: 31, Apr: 30, May: 31, Jun: 30, Jul: 31, Aug: 31, Sep: 30, Oct: 31, Nov: 30, Dec: 31
  }.freeze
  VALID_MONTH_NAMES = VALID_MONTH_NAME_DAY_LIST.keys.freeze
  TIME_SLOT_COUNT_PER_CHANNEL = {
    'ticket' => 1
  }.freeze
end
