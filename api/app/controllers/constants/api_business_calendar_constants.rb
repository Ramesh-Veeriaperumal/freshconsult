# frozen_string_literal: true

module ApiBusinessCalendarConstants
  ALL_TIME_AVAILABLE = '24_7_availability'
  CUSTOM_AVAILABLE = 'custom'
  TICKET_CHANNEL = 'ticket'
  PERMITTED_PARAMS = %i[id name description time_zone channel_business_hours holidays].freeze
  PHONE_CHANNEL = 'phone'
  CHAT_CHANNEL = 'chat'
  CHAT_DEFAULT_AWAY_MESSAGE = 'We are away now'
  CREATE_FIELDS = (PERMITTED_PARAMS - %i[id]).freeze
  UPDATE_FIELDS = CREATE_FIELDS
  HOLIDAYS_PERMITTED_PARAMS = %w[date name].freeze
  VALID_CHANNEL_PARAMS = [TICKET_CHANNEL].freeze
  VALID_CHANNEL_PARAMS_OMNI = VALID_CHANNEL_PARAMS | [CHAT_CHANNEL, PHONE_CHANNEL].freeze
  TIME_SLOTS_PARAMS = %w[start_time end_time].freeze
  VALID_MINUTES_DATA = (00..59).to_a.freeze
  CHANNEL_BUSINESS_HOURS_PARAMS = %w[channel business_hours_type business_hours].freeze
  CHAT_CHANNEL_BUSINESS_HOURS_PARAMS = CHANNEL_BUSINESS_HOURS_PARAMS | %w[away_message].freeze
  BUSINESS_HOURS_TYPE_ALLOWED = %w[24_7_availability custom].freeze
  TIMEZONES = ActiveSupport::TimeZone.all.map(&:name).freeze

  CHANNEL_PARAMS = HashWithIndifferentAccess.new(
    "#{TICKET_CHANNEL}": CHANNEL_BUSINESS_HOURS_PARAMS,
    "#{CHAT_CHANNEL}": CHAT_CHANNEL_BUSINESS_HOURS_PARAMS,
    "#{PHONE_CHANNEL}": CHANNEL_BUSINESS_HOURS_PARAMS
  )
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

  FRESHDESK_PRODUCT = 'freshdesk'
  FRESHCHAT_PRODUCT = 'freshchat'
  FRESHCALLER_PRODUCT = 'freshcaller'
  API_CHANNEL_TO_PRODUCT = HashWithIndifferentAccess.new(
    "#{TICKET_CHANNEL}": FRESHDESK_PRODUCT,
    "#{CHAT_CHANNEL}": FRESHCHAT_PRODUCT,
    "#{PHONE_CHANNEL}": FRESHCALLER_PRODUCT
  )
  API_PRODUCT_TO_CHANNEL = API_CHANNEL_TO_PRODUCT.invert
end
