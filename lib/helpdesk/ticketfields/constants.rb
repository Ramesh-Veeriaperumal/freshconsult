module Helpdesk::Ticketfields::Constants
  include FlexifieldConstants

  DROPDOWN_FIELD_COUNT  = 80
  NUMBER_FIELD_COUNT    = 20
  DATE_FIELD_COUNT      = 10
  CHECKBOX_FIELD_COUNT  = 10
  TEXT_FIELD_COUNT      = 10
  DECIMAL_FIELD_COUNT   = 10

  DROPDOWN_FIELDS = (1..DROPDOWN_FIELD_COUNT).collect { |n| "ffs_#{format('%02d', n)}" }.freeze
  NUMBER_FIELDS   = (1..NUMBER_FIELD_COUNT).collect { |n| "ff_int#{format('%02d', n)}" }.freeze
  DATE_FIELDS     = (1..DATE_FIELD_COUNT).collect { |n| "ff_date#{format('%02d', n)}" }.freeze
  CHECKBOX_FIELDS = (1..CHECKBOX_FIELD_COUNT).collect { |n| "ff_boolean#{format('%02d', n)}" }.freeze
  TEXT_FIELDS     = (1..TEXT_FIELD_COUNT).collect { |n| "ff_text#{format('%02d', n)}" }.freeze
  DECIMAL_FIELDS  = (1..DECIMAL_FIELD_COUNT).collect { |n| "ff_decimal#{format('%02d', n)}" }.freeze

  # Whenever you add new fields here, ensure that you add it in search indexing.
  FIELD_COLUMN_MAPPING = {
    text:          ['text', SERIALIZED_SLT_FIELDS, SERIALIZED_SLT_FIELDS.length],
    nested_field:  [['text', 'dropdown'], DROPDOWN_FIELDS, DROPDOWN_FIELD_COUNT],
    dropdown:      [['text', 'dropdown'], DROPDOWN_FIELDS, DROPDOWN_FIELD_COUNT],
    number:        ['number', NUMBER_FIELDS, NUMBER_FIELD_COUNT],
    checkbox:      ['checkbox', CHECKBOX_FIELDS, CHECKBOX_FIELD_COUNT],
    date:          ['date', DATE_FIELDS, DATE_FIELD_COUNT],
    date_time:     ['date_time', DATE_FIELDS, DATE_FIELD_COUNT],
    paragraph:     ['paragraph', SERIALIZED_MLT_FIELDS, SERIALIZED_MLT_FIELDS.length],
    decimal:       ['decimal', DECIMAL_FIELDS, DECIMAL_FIELD_COUNT],
    encrypted_text:['encrypted_text', SERIALIZED_ESLT_FIELDS, SERIALIZED_ESLT_FIELDS.length]
  }.freeze

  FFS_LIMIT = 80

  MAX_ALLOWED_COUNT = {
    string:  DROPDOWN_FIELD_COUNT,
    text:    TEXT_FIELD_COUNT,
    number:  NUMBER_FIELD_COUNT,
    date:    DATE_FIELD_COUNT,
    boolean: CHECKBOX_FIELD_COUNT,
    decimal: DECIMAL_FIELD_COUNT
  }.freeze

  MAX_ALLOWED_COUNT_DN = {
    string:  SERIALIZED_SLT_FIELDS.length,
    text:    SERIALIZED_MLT_FIELDS.length,
    number:  NUMBER_FIELD_COUNT,
    date:    DATE_FIELD_COUNT,
    boolean: CHECKBOX_FIELD_COUNT,
    decimal: DECIMAL_FIELD_COUNT
  }.freeze

  CUSTOM_FIELD_LABEL_PREFIX = 'cf_'
  ENCRYPTED_FIELD_LABEL_PREFIX = 'cf_enc_'
end
