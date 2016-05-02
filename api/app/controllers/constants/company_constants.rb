module CompanyConstants
  ARRAY_FIELDS = ['domains'].freeze
  HASH_FIELDS = ['custom_fields'].freeze
  COMPLEX_FIELDS = ARRAY_FIELDS | HASH_FIELDS
  INDEX_FIELDS = %w( name ).freeze

  FIELDS = %w(name description note).freeze | ARRAY_FIELDS | HASH_FIELDS
  FIELD_MAPPINGS = { :"company_domains.base" => :domains, :"company_domains.domain" => :domains }.freeze

  ATTRIBUTES_TO_BE_STRIPPED = %w(name description note domains custom_fields).freeze
end.freeze
