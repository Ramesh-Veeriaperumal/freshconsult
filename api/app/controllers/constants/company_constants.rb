module CompanyConstants
  ARRAY_FIELDS = ['domains'].freeze
  HASH_FIELDS = ['custom_fields'].freeze
  COMPLEX_FIELDS = ARRAY_FIELDS | HASH_FIELDS
  INDEX_FIELDS = %w( updated_since name ).freeze

  FIELDS = %w(name description domains note).freeze | ARRAY_FIELDS.map { |x| Hash[x, [nil]] } | HASH_FIELDS

  ATTRIBUTES_TO_BE_STRIPPED = %w(name description note domains custom_fields).freeze

  DEFAULT_FIELD_VALIDATIONS =  {
    description:  { data_type: { rules: String } },
    note: { data_type: { rules: String } },
    domains:  { data_type: { rules: Array, allow_nil: false }, array: { data_type: { rules: String } }, string_rejection: { excluded_chars: [','] } }
  }.freeze
end.freeze
