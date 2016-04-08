module CompanyConstants
  ARRAY_FIELDS = ['domains'].freeze
  HASH_FIELDS = ['custom_fields'].freeze
  COMPLEX_FIELDS = ARRAY_FIELDS | HASH_FIELDS

  FIELDS = %w(name description note).freeze | ARRAY_FIELDS | HASH_FIELDS

  ATTRIBUTES_TO_BE_STRIPPED = %w(name description note domains custom_fields).freeze
end.freeze
