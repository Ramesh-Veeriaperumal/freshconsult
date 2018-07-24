module Segments::EsQueryConstants
  # commented lines are to support date fields
  OPERTORS = ['is_in', 'is_greater_than', 'is_less_than', 'equal', 'bool', 'is_between'].freeze
  NUMBER_KEYS = ['company_id'].freeze
  DATE_OPERATIONS = ['today', 'yesterday'].freeze
  ES_FIELD_MAPPINGS = {
    'tag_names' => 'tag',
    'company_name' => 'company_id'
  }.freeze
  CREATED_AT = 'created_at'.freeze
  ONE_WEEK = 7
  ONE_MONTH = 30

  GREATER_THAN = '>'.freeze
  LESSER_THAN = '<'.freeze

  INTEGER = 'int'.freeze
  # DATE_TYPE =  'date'.freeze
end
