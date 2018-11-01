module Proactive::Constants
  PROACTIVE_SERVICE_ROUTES = { rules_route: 'api/v1/rules' }.freeze
  SUCCESS_CODES = [200, 201, 204].freeze

  EQUALS = 'equals'.freeze
  NOT_EQUALS = 'not_equals'.freeze
  CONTAINS = 'contains'.freeze
  NOT_CONTAINS = 'not_contains'.freeze
  STARTS_WITH = 'starts_with'.freeze
  ENDS_WITH = 'ends_with'.freeze
  LESS_THAN = 'less_than'.freeze
  GREATER_THAN = 'greater_than'.freeze
  CHECKED = 'checked'.freeze
  NOT_CHECKED = 'not_checked'.freeze
  IN = 'in'.freeze
  NOT_IN = 'not_in'.freeze
  ALL_OF = 'all_of'.freeze
  ANY_OF = 'any_of'.freeze
  NONE_OF = 'none_of'.freeze

  CF_TYPES = {
    'custom_text' => 'text',
    'custom_dropdown' => 'multi_text',
    'custom_checkbox' => 'boolean',
    'custom_number'   => 'number',
    'custom_decimal'  => 'decimal',
    'custom_date'     => 'date',
    'custom_url'      => 'text',
    'custom_phone_number' => 'text',
    'custom_paragraph' => 'paragraph'
  }.freeze

  CF_CUSTOMER_MAPPING = {
    'custom_text'         => [EQUALS, NOT_EQUALS, CONTAINS, NOT_CONTAINS,
                              STARTS_WITH, ENDS_WITH],
    'custom_dropdown'     => [IN, NOT_IN],
    'custom_checkbox'     => [CHECKED, NOT_CHECKED],
    'custom_number'       => [EQUALS, NOT_EQUALS, LESS_THAN, GREATER_THAN],
    'custom_url'          => [EQUALS, NOT_EQUALS, CONTAINS, NOT_CONTAINS,
                              STARTS_WITH, ENDS_WITH],
    'custom_phone_number' => [EQUALS, NOT_EQUALS, CONTAINS, NOT_CONTAINS,
                              STARTS_WITH, ENDS_WITH],
    'custom_paragraph'    => [EQUALS, NOT_EQUALS, CONTAINS, NOT_CONTAINS,
                              STARTS_WITH, ENDS_WITH],
    'custom_date'         => [EQUALS, NOT_EQUALS, LESS_THAN, GREATER_THAN]
  }.freeze

  EVENTS = ['abandoned_cart', 'delivery_feedback'].freeze
  LOCALES_AVAILABLE = I18n.available_locales.sort.map { |locale| { name: locale.to_s } }.freeze
  TIMEZONES_AVAILABLE = ActiveSupport::TimeZone.all.map { |time_zone| { name: time_zone.name.to_s, label: time_zone.to_s } }

  TEXT_OPERATIONS = [EQUALS, NOT_EQUALS, CONTAINS, NOT_CONTAINS,
                     STARTS_WITH, ENDS_WITH].freeze
  MULTI_TEXT_OPERATIONS = [IN, NOT_IN].freeze
  DATE_OPERATIONS = [EQUALS, NOT_EQUALS, LESS_THAN, GREATER_THAN].freeze
  TAG_OPERATIONS = [ALL_OF, ANY_OF, NONE_OF].freeze
  ALLOWED_ENTITIES = %w[contact_fields company_fields shopify_fields].freeze


  #Date Validation constants
  ISO_DATE_DELIMITER     = 'T'.freeze
  TIME_EXCEPTION_MSG     = 'invalid_sec_or_zone'.freeze
  UNHANDLED_HOUR_VALUE   = '24'.freeze
  UNHANDLED_SECOND_VALUE = ':60'.freeze
  ZONE_PLUS_PREFIX       = '+'.freeze
  ZONE_MINUS_PREFIX      = '-'.freeze
  ISO_TIME_DELIMITER     = ':'.freeze
  FORMAT_EXCEPTION_MSG   = 'invalid_format'.freeze
  DATE_TIME_REGEX        = /^\d{4}-\d{2}-\d{2}/
  DATE_REGEX             = /^\d{4}-\d{2}-\d{2}$/
end
