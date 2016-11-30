module CompanyConstants
  ARRAY_FIELDS = ['domains'].freeze
  HASH_FIELDS = ['custom_fields'].freeze
  COMPLEX_FIELDS = ARRAY_FIELDS | HASH_FIELDS

  FIELDS = %w(name description note).freeze | ARRAY_FIELDS | HASH_FIELDS
  INDEX_FIELDS = %w(include letter).freeze
  ACTIVITIES_FIELDS = %w(type).freeze

  ACTIVITY_TYPES = %w(tickets archived_tickets).freeze

  FIELD_MAPPINGS = { :"company_domains.base" => :domains, :"company_domains.domain" => :domains }.freeze
  SIDE_LOADING = %w(contacts_count sla_policies).freeze
  ATTRIBUTES_TO_BE_STRIPPED = %w(name description note domains custom_fields).freeze
  MAX_ACTIVITIES_COUNT = 10

end.freeze
