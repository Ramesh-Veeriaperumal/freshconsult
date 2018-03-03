module FlexifieldConstants

  SERIALIZED_SLT_FIELDS_1 = (1..200).collect{ |n| "dn_slt_#{"%03d" % n}"}
  SERIALIZED_SLT_FIELDS_2 = (201..400).collect{ |n| "dn_slt_#{"%03d" % n}"}
  SERIALIZED_SLT_FIELDS   = SERIALIZED_SLT_FIELDS_1 + SERIALIZED_SLT_FIELDS_2 
  # SERIALIZED_NUM_FIELDS = (1..3).collect{ |n| "dn_num_#{"%03d" % n}"}
  # SERIALIZED_DEC_FIELDS = (1..3).collect{ |n| "dn_dec_#{"%03d" % n}"}

  SERIALIZED_COLUMN_MAPPING = [ 
    #[field_names,          db_column,  flexifield_type,  validation_methods ]
    [SERIALIZED_SLT_FIELDS_1, :slt_text_11,       "text",           [:trim_length_of_slt]],
    [SERIALIZED_SLT_FIELDS_2, :slt_text_12,       "text",           [:trim_length_of_slt]]
    # [SERIALIZED_NUM_FIELDS,   :int_text_13,       "number",         [:convert_to_integer]],
    # [SERIALIZED_DEC_FIELDS,   :decimal_text_14,   "decimal",        [:convert_to_decimal]]
  ]

  SERIALIZED_COLUMN_MAPPING_BY_DB_COLUMN = SERIALIZED_COLUMN_MAPPING.group_by{|array| array[1]}.each_with_object({}){|(k,v),result| result[k] = v.map(&:first).flatten!.sort!}
  SERIALIZED_COLUMN_MAPPING_BY_ATTRIBUTES = SERIALIZED_COLUMN_MAPPING.map{|array| array[0].map{|key| [key, array[1]]} }.flatten(1).to_h
  
  SERIALIZED_COLUMN_MAPPING_BY_TYPE = 
  SERIALIZED_COLUMN_MAPPING.group_by{|array| array[2]}.each_with_object({}){|(k,v),result| result[k] = v.map(&:first).flatten!.sort!}
  SERIALIZED_COLUMN_SANITIZATION_METHODS =
  SERIALIZED_COLUMN_MAPPING.group_by{|array| array[3]}.each_with_object({}){|(k,v),result| result[k] = v.map(&:first).flatten!.sort!}

  SERIALIZED_DB_COLUMNS = SERIALIZED_COLUMN_MAPPING_BY_DB_COLUMN.keys
  SERIALIZED_ATTRIBUTES = SERIALIZED_COLUMN_MAPPING_BY_ATTRIBUTES.keys
  SERIALIZED_TYPES      = SERIALIZED_COLUMN_MAPPING_BY_TYPE.keys

  CREATED_SERIALIZED_COLUMNS = [:slt_text_11, :slt_text_12, :int_text_13, :decimal_text_14, :date_text_15, :boolean_text_16]

end
