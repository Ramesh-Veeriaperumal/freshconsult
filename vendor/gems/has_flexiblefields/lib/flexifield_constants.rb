module FlexifieldConstants
  SERIALIZED_SLT_FIELDS_1 = (1..200).collect { |n| "dn_slt_#{format('%03d', n)}" }.freeze
  SERIALIZED_SLT_FIELDS_2 = (201..400).collect { |n| "dn_slt_#{format('%03d', n)}" }.freeze
  SERIALIZED_SLT_FIELDS   = (SERIALIZED_SLT_FIELDS_1 + SERIALIZED_SLT_FIELDS_2).freeze
  SERIALIZED_MLT_FIELDS_1 = (1..10).collect { |n| "dn_mlt_#{format('%03d', n)}" }.freeze
  SERIALIZED_MLT_FIELDS_2 = (11..20).collect { |n| "dn_mlt_#{format('%03d', n)}" }.freeze
  SERIALIZED_MLT_FIELDS_3 = (21..30).collect { |n| "dn_mlt_#{format('%03d', n)}" }.freeze
  SERIALIZED_MLT_FIELDS_4 = (31..40).collect { |n| "dn_mlt_#{format('%03d', n)}" }.freeze
  SERIALIZED_MLT_FIELDS_5 = (41..50).collect { |n| "dn_mlt_#{format('%03d', n)}" }.freeze
  SERIALIZED_MLT_FIELDS   = (SERIALIZED_MLT_FIELDS_1 + SERIALIZED_MLT_FIELDS_2 + SERIALIZED_MLT_FIELDS_3 + SERIALIZED_MLT_FIELDS_4 + SERIALIZED_MLT_FIELDS_5).freeze
  SERIALIZED_ESLT_FIELDS  = (1..50).collect { |n| "dn_eslt_#{format('%03d', n)}" }.freeze
  # SERIALIZED_NUM_FIELDS = (1..3).collect{ |n| "dn_num_#{"%03d" % n}"}
  # SERIALIZED_DEC_FIELDS = (1..3).collect{ |n| "dn_dec_#{"%03d" % n}"}

  TEXT_FLEXIFIELD_TYPE = 'text'
  PARAGRAPH_FLEXIFIELD_TYPE = 'paragraph'
  ENCRYPTED_FLEXIFIELD_TYPE = 'encrypted_text'

  SERIALIZED_COLUMN_MAPPING = [
    # [field_names,          db_column,  flexifield_type,  write_sanitization_methods, read_sanitization_methods, validation_methods ]
    [SERIALIZED_SLT_FIELDS_1, :slt_text_11,  TEXT_FLEXIFIELD_TYPE,      [:trim_length_of_slt], [], []],
    [SERIALIZED_SLT_FIELDS_2, :slt_text_12,  TEXT_FLEXIFIELD_TYPE,      [:trim_length_of_slt], [], []],
    [SERIALIZED_MLT_FIELDS_1, :mlt_text_17,  PARAGRAPH_FLEXIFIELD_TYPE, [:trim_length_of_mlt], [], []],
    [SERIALIZED_MLT_FIELDS_2, :mlt_text_18,  PARAGRAPH_FLEXIFIELD_TYPE, [:trim_length_of_mlt], [], []],
    [SERIALIZED_MLT_FIELDS_3, :mlt_text_19,  PARAGRAPH_FLEXIFIELD_TYPE, [:trim_length_of_mlt], [], []],
    [SERIALIZED_MLT_FIELDS_4, :mlt_text_20,  PARAGRAPH_FLEXIFIELD_TYPE, [:trim_length_of_mlt], [], []],
    [SERIALIZED_MLT_FIELDS_5, :mlt_text_21,  PARAGRAPH_FLEXIFIELD_TYPE, [:trim_length_of_mlt], [], []],
    [SERIALIZED_ESLT_FIELDS,  :eslt_text_22, ENCRYPTED_FLEXIFIELD_TYPE, [:trim_length_of_slt, :encrypt_field_value], [:decrypt_field_value], []]
    # [SERIALIZED_NUM_FIELDS,   :int_text_13,       "number",         [:convert_to_integer], []],
    # [SERIALIZED_DEC_FIELDS,   :decimal_text_14,   "decimal",        [:convert_to_decimal], []]
  ].freeze

  SERIALIZED_COLUMN_MAPPING_BY_DB_COLUMN = SERIALIZED_COLUMN_MAPPING.group_by { |array| array[1] }.each_with_object({}) { |(k, v), result| result[k] = v.map(&:first).flatten!.sort! }.freeze

  SERIALIZED_COLUMN_MAPPING_BY_ATTRIBUTES = SERIALIZED_COLUMN_MAPPING.flat_map { |array| array[0].map { |key| [key, array[1]] } }.to_h

  SERIALIZED_COLUMN_MAPPING_BY_TYPE =
    SERIALIZED_COLUMN_MAPPING.group_by { |array| array[2] }.each_with_object({}) { |(k, v), result| result[k] = v.map(&:first).flatten!.sort! }.freeze

  SERIALIZED_COLUMN_SANITIZATION_METHODS =
    SERIALIZED_COLUMN_MAPPING.group_by { |array| array[3] }.each_with_object({}) { |(k, v), result| result[k] = v.map(&:first).flatten!.sort! }.freeze

  SERIALIZED_COLUMN_WRITE_SANITIZATION_BY_DB_COLUMN = SERIALIZED_COLUMN_MAPPING.map { |array| [array[1], array[3]] }.to_h.freeze

  SERIALIZED_COLUMN_READ_SANITIZATION_BY_DB_COLUMN = SERIALIZED_COLUMN_MAPPING.map { |array| [array[1], array[4]] }.to_h.freeze

  SERIALIZED_COLUMN_VALIDATION_BY_DB_COLUMN = SERIALIZED_COLUMN_MAPPING.map { |array| [array[1], array[5]] }.to_h.freeze

  SERIALIZED_DB_COLUMNS = SERIALIZED_COLUMN_MAPPING_BY_DB_COLUMN.keys.freeze
  SERIALIZED_ATTRIBUTES = SERIALIZED_COLUMN_MAPPING_BY_ATTRIBUTES.keys.freeze
  SERIALIZED_TYPES      = SERIALIZED_COLUMN_MAPPING_BY_TYPE.keys.freeze

  UNUSED_SERIALIZED_COLUMNS = [:int_text_13, :decimal_text_14, :date_text_15, :boolean_text_16].freeze

  CREATED_SERIALIZED_COLUMNS = (SERIALIZED_COLUMN_MAPPING.map(&:second) | UNUSED_SERIALIZED_COLUMNS).freeze

  SLT_CHARACTER_LENGTH  = 255
  MLT_CHARACTER_LENGTH  = 1500

  NON_SERIALIZED_MLT_FIELDS = (1..10).collect { |n| "text_#{format('%02d', n)}" }.freeze

  NON_SERIALIZED_COLUMNS = NON_SERIALIZED_MLT_FIELDS.freeze
end
