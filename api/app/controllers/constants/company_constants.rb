module CompanyConstants
  ARRAY_FIELDS = ['domains'].freeze
  HASH_FIELDS = ['custom_fields'].freeze
  COMPLEX_FIELDS = ARRAY_FIELDS | HASH_FIELDS

  FIELDS = %w(name description note).freeze | ARRAY_FIELDS | HASH_FIELDS

  ATTRIBUTES_TO_BE_STRIPPED = %w(name description note domains custom_fields).freeze

  DEFAULT_FIELD_VALIDATIONS =  {
    description:  { data_type: { rules: String } },
    note: { data_type: { rules: String } },
    domains:  { data_type: { rules: Array, allow_unset: true, allow_nil: false }, array: { data_type: { rules: String } }, string_rejection: { excluded_chars: [','], allow_nil: true } }
  }.freeze
end.freeze
