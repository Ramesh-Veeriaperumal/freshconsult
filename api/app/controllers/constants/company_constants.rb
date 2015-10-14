module CompanyConstants
  ARRAY_FIELDS = [{ 'domains' => [] }]
  FIELDS = %w(name description domains note custom_fields) | ARRAY_FIELDS

  FIELDS_TO_BE_STRIPPED = %w(name description note domains custom_fields)

  DEFAULT_FIELD_VALIDATIONS =  {
        description:  { data_type: { rules: String } },
        note: { data_type: { rules: String } },
        domains:  { data_type: { rules: Array }, array: { data_type: { rules: String } }, string_rejection: { excluded_chars: [','] } }
      }
end
