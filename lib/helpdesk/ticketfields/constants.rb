module Helpdesk::Ticketfields::Constants
  include FlexifieldConstants

  DROPDOWN_FIELD_COUNT  = 80
  NUMBER_FIELD_COUNT    = 20
  DATE_FIELD_COUNT      = 10
  CHECKBOX_FIELD_COUNT  = 10
  TEXT_FIELD_COUNT      = 10
  DECIMAL_FIELD_COUNT   = 10


  TICKET_FIELD_DATA_DROPDOWN_COUNT = 250
  TICKET_FIELD_DATA_CHECKBOX_COUNT = 30
  TICKET_FIELD_DATA_NUMBER_COUNT = 30
  TICKET_FIELD_DATA_DATE_FIELD_COUNT = 30
  SERIALIZED_MULTILINE_FIELD_COUNT = 50
  SERIALIZED_ENCRYPTED_FIELD_COUNT = 50
  SERIALIZED_SINGLE_LINE_FIELD_COUNT = 400

  DROPDOWN_FIELDS = (1..DROPDOWN_FIELD_COUNT).collect { |n| "ffs_#{format('%02d', n)}" }.freeze
  NUMBER_FIELDS   = (1..NUMBER_FIELD_COUNT).collect { |n| "ff_int#{format('%02d', n)}" }.freeze
  DATE_FIELDS     = (1..DATE_FIELD_COUNT).collect { |n| "ff_date#{format('%02d', n)}" }.freeze
  CHECKBOX_FIELDS = (1..CHECKBOX_FIELD_COUNT).collect { |n| "ff_boolean#{format('%02d', n)}" }.freeze
  TEXT_FIELDS     = (1..TEXT_FIELD_COUNT).collect { |n| "ff_text#{format('%02d', n)}" }.freeze
  DECIMAL_FIELDS  = (1..DECIMAL_FIELD_COUNT).collect { |n| "ff_decimal#{format('%02d', n)}" }.freeze


  TICKET_FIELD_DATA_DROPDOWN_FIELDS = (1..TICKET_FIELD_DATA_DROPDOWN_COUNT).collect { |n| "ffs_#{format('%02d', n)}" }.freeze
  TICKET_FIELD_DATA_CHECKBOX_FIELDS = (1..TICKET_FIELD_DATA_CHECKBOX_COUNT).collect { |n| "ff_boolean#{format('%02d', n)}" }.freeze
  TICKET_FIELD_DATA_NUMBER_FIELDS = (1..TICKET_FIELD_DATA_NUMBER_COUNT).collect { |n| "ff_int#{format('%02d', n)}" }.freeze
  TICKET_FIELD_DATA_DATE_FIELDS = (1..TICKET_FIELD_DATA_DATE_FIELD_COUNT).collect { |n| "ff_date#{format('%02d', n)}" }.freeze

  # Whenever you add new fields here, ensure that you add it in search indexing.
  FIELD_COLUMN_MAPPING = {
    text:          [['text', 'file'], SERIALIZED_SLT_FIELDS, SERIALIZED_SLT_FIELDS.length],
    nested_field:  [['text', 'dropdown'], DROPDOWN_FIELDS, DROPDOWN_FIELD_COUNT],
    dropdown:      [['text', 'dropdown'], DROPDOWN_FIELDS, DROPDOWN_FIELD_COUNT],
    number:        ['number', NUMBER_FIELDS, NUMBER_FIELD_COUNT],
    checkbox:      ['checkbox', CHECKBOX_FIELDS, CHECKBOX_FIELD_COUNT],
    date:          [['date', 'date_time'], DATE_FIELDS, DATE_FIELD_COUNT],
    date_time:     [['date', 'date_time'], DATE_FIELDS, DATE_FIELD_COUNT],
    paragraph:     ['paragraph', SERIALIZED_MLT_FIELDS, SERIALIZED_MLT_FIELDS.length],
    decimal:       ['decimal', DECIMAL_FIELDS, DECIMAL_FIELD_COUNT],
    encrypted_text:['encrypted_text', SERIALIZED_ESLT_FIELDS, SERIALIZED_ESLT_FIELDS.length],
    file:          [['text', 'file'], SERIALIZED_SLT_FIELDS, SERIALIZED_SLT_FIELDS.length]
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

  TICKET_FIELD_DATA_COUNT = {
    string:  TICKET_FIELD_DATA_DROPDOWN_COUNT,
    text:    TEXT_FIELD_COUNT,
    number:  TICKET_FIELD_DATA_NUMBER_COUNT,
    date:    TICKET_FIELD_DATA_DATE_FIELD_COUNT,
    boolean: TICKET_FIELD_DATA_CHECKBOX_COUNT,
    decimal: DECIMAL_FIELD_COUNT
  }.freeze

  TICKET_FIELD_DATA_COLUMN_MAPPING = {
    text:           [['text', 'file'], SERIALIZED_SLT_FIELDS, SERIALIZED_SLT_FIELDS.length],
    nested_field:   [['text', 'dropdown'], TICKET_FIELD_DATA_DROPDOWN_FIELDS, TICKET_FIELD_DATA_DROPDOWN_COUNT],
    dropdown:       [['text', 'dropdown'], TICKET_FIELD_DATA_DROPDOWN_FIELDS, TICKET_FIELD_DATA_DROPDOWN_COUNT],
    number:         ['number', TICKET_FIELD_DATA_NUMBER_FIELDS, TICKET_FIELD_DATA_NUMBER_COUNT],
    checkbox:       ['checkbox', TICKET_FIELD_DATA_CHECKBOX_FIELDS, TICKET_FIELD_DATA_CHECKBOX_COUNT],
    date:           [['date', 'date_time'], TICKET_FIELD_DATA_DATE_FIELDS, TICKET_FIELD_DATA_DATE_FIELD_COUNT],
    date_time:      [['date', 'date_time'], TICKET_FIELD_DATA_DATE_FIELDS, TICKET_FIELD_DATA_DATE_FIELD_COUNT],
    paragraph:      ['paragraph', SERIALIZED_MLT_FIELDS, SERIALIZED_MLT_FIELDS.length],
    decimal:        ['decimal', DECIMAL_FIELDS, DECIMAL_FIELD_COUNT],
    encrypted_text: ['encrypted_text', SERIALIZED_ESLT_FIELDS, SERIALIZED_ESLT_FIELDS.length],
    file:           [['text', 'file'], SERIALIZED_SLT_FIELDS, SERIALIZED_SLT_FIELDS.length]
  }.freeze

  MAX_ALLOWED_COUNT_DN = {
    string:  SERIALIZED_SLT_FIELDS.length,
    text:    SERIALIZED_MLT_FIELDS.length,
    number:  NUMBER_FIELD_COUNT,
    date:    DATE_FIELD_COUNT,
    boolean: CHECKBOX_FIELD_COUNT,
    decimal: DECIMAL_FIELD_COUNT
  }.freeze

  TEXT_AND_DROPDOWN_FIELD_DETAILS = {
    'denormalized_and_text': ['dn', 'text'],
    'ffs_and_text_only': ['ffs', 'text'],
    'ffs_and_dropdown_only': ['ffs', 'dropdown']
  }.freeze

  DEFAULT_MAX_ALLOWED_FIELDS = {
    paragraph: TEXT_FIELD_COUNT,
    number: NUMBER_FIELD_COUNT,
    date: DATE_FIELD_COUNT,
    checkbox: CHECKBOX_FIELD_COUNT,
    decimal: DECIMAL_FIELD_COUNT,
    encrypted_text: SERIALIZED_ESLT_FIELDS.length
  }.freeze

  REVAMPED_FLEXIFIELD_LIMITS = {
      text:           [%w(file text), SERIALIZED_SLT_FIELDS, SERIALIZED_SINGLE_LINE_FIELD_COUNT],
      nested_field:   [%w(text dropdown), DROPDOWN_FIELDS, DROPDOWN_FIELD_COUNT],
      dropdown:       [%w(text dropdown), DROPDOWN_FIELDS, DROPDOWN_FIELD_COUNT],
      number:         ['number', NUMBER_FIELDS, NUMBER_FIELD_COUNT],
      checkbox:       ['checkbox', CHECKBOX_FIELDS, CHECKBOX_FIELD_COUNT],
      date:           [%w(date date_time),  DATE_FIELDS, DATE_FIELD_COUNT],
      date_time:      [%w(date date_time), DATE_FIELDS, DATE_FIELD_COUNT],
      paragraph:      ['paragraph', SERIALIZED_MLT_FIELDS, SERIALIZED_MULTILINE_FIELD_COUNT],
      decimal:        ['decimal', DECIMAL_FIELDS, DECIMAL_FIELD_COUNT],
      encrypted_text: ['encrypted_text', SERIALIZED_ESLT_FIELDS, SERIALIZED_ENCRYPTED_FIELD_COUNT],
      file:           [%w(file text), SERIALIZED_SLT_FIELDS, SERIALIZED_SINGLE_LINE_FIELD_COUNT]
  }.freeze

  REVAMPED_TICKET_FIELD_DATA_LIMITS = {
      text:           [%w(file text), SERIALIZED_SLT_FIELDS, SERIALIZED_SINGLE_LINE_FIELD_COUNT],
      nested_field:   ['dropdown', TICKET_FIELD_DATA_DROPDOWN_FIELDS, TICKET_FIELD_DATA_DROPDOWN_COUNT],
      dropdown:       ['dropdown', TICKET_FIELD_DATA_DROPDOWN_FIELDS, TICKET_FIELD_DATA_DROPDOWN_COUNT],
      number:         ['number', TICKET_FIELD_DATA_NUMBER_FIELDS, TICKET_FIELD_DATA_NUMBER_COUNT],
      checkbox:       ['checkbox', TICKET_FIELD_DATA_CHECKBOX_FIELDS, TICKET_FIELD_DATA_CHECKBOX_COUNT],
      date:           [%w(date date_time), TICKET_FIELD_DATA_DATE_FIELDS, TICKET_FIELD_DATA_DATE_FIELD_COUNT],
      date_time:      [%w(date date_time), TICKET_FIELD_DATA_DATE_FIELDS, TICKET_FIELD_DATA_DATE_FIELD_COUNT],
      paragraph:      ['paragraph', SERIALIZED_MLT_FIELDS, SERIALIZED_MULTILINE_FIELD_COUNT],
      decimal:        ['decimal', DECIMAL_FIELDS, DECIMAL_FIELD_COUNT],
      encrypted_text: ['encrypted_text', SERIALIZED_ESLT_FIELDS, SERIALIZED_ENCRYPTED_FIELD_COUNT],
      file:           [%w(file text), SERIALIZED_SLT_FIELDS, SERIALIZED_SINGLE_LINE_FIELD_COUNT]
  }.freeze

  MIN_CHOICES_COUNT = 1

  CUSTOM_FIELD_LABEL_PREFIX = 'cf_'
  ENCRYPTED_FIELD_LABEL_PREFIX = 'cf_enc_'
  ENCRYPTED_LABEL_PREFIX_WITHOUT_CF = 'enc_'

  PLUCKED_COLUMN_FOR_CHOICES = %i[id pickable_id pickable_type position value picklist_id].freeze
  PICKLIST_CHOICE_BATCH_SIZE = 300

  VALID_FIELD_TYPE = %w[text paragraph dropdown checkbox number date date_time decimal nested_field encrypted_text].freeze
end
