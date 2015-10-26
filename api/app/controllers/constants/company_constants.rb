module CompanyConstants
  ARRAY_FIELDS = ['domains']
  HASH_FIELDS = ['custom_fields']
  COMPLEX_FIELDS = ARRAY_FIELDS | HASH_FIELDS

  FIELDS = %w(name description domains note) | ARRAY_FIELDS.map { |x| Hash[x, [nil]] } | HASH_FIELDS

  FIELDS_TO_BE_STRIPPED = %w(name description note domains custom_fields)

  DEFAULT_FIELD_VALIDATIONS =  {
    description:  { data_type: { rules: String } },
    note: { data_type: { rules: String } },
    domains:  { data_type: { rules: Array, allow_nil: true }, array: { data_type: { rules: String } }, string_rejection: { excluded_chars: [','] } }
  }
end
