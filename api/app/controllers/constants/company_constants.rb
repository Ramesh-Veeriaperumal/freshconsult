module CompanyConstants
  ARRAY_FIELDS = [{ 'domains' => [] }]
  FIELDS = %w(name description domains note) | ARRAY_FIELDS

  FIELDS_TO_BE_STRIPPED = %w(name description note domains custom_fields)
end
