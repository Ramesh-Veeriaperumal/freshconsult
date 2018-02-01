module CompanyConstants
  ARRAY_FIELDS = ['domains'].freeze
  HASH_FIELDS = ['custom_fields'].freeze
  COMPLEX_FIELDS = ARRAY_FIELDS | HASH_FIELDS


  FIELDS = %w(name description note health_score
              account_tier renewal_date industry).freeze | ARRAY_FIELDS | HASH_FIELDS
  FIELD_MAPPINGS = { :"company_domains.base" => :domains, :"company_domains.domain" => :domains }.freeze
  DEFAULT_DROPDOWN_FIELDS = %i(health_score account_tier industry)
  VALIDATABLE_DELEGATOR_ATTRIBUTES = %w(custom_field health_score account_tier industry).freeze

  ATTRIBUTES_TO_BE_STRIPPED = %w(name description note domains custom_fields).freeze
end.freeze
