module CompanyConstants
  ARRAY_FIELDS = ['domains'].freeze
  HASH_FIELDS = ['custom_fields'].freeze
  COMPLEX_FIELDS = ARRAY_FIELDS | HASH_FIELDS

  EXPORT_ARRAY_FIELDS = %w[default_fields custom_fields].freeze
  EXPORT_FIELDS = %w[fields].freeze
  FIELDS = %w(name description note avatar_id avatar health_score
              account_tier renewal_date industry).freeze | ARRAY_FIELDS | HASH_FIELDS
  # INDEX_FIELDS = %w(query_hash include letter filter).freeze
  INDEX_FIELDS = ['query_hash', 'include', 'letter', 'filter', 'ids'].freeze
  ACTIVITIES_FIELDS = %w(type).freeze
  BULK_ACTION_METHODS = [:bulk_delete].freeze
  DEFAULT_DROPDOWN_FIELDS = %i(health_score account_tier industry)

  FIELD_MAPPINGS = { :"company_domains.base" => :domains, :"company_domains.domain" => :domains }.freeze
  DEFAULT_DROPDOWN_FIELDS = %i(health_score account_tier industry)
  VALIDATABLE_DELEGATOR_ATTRIBUTES = %w(custom_field health_score account_tier industry).freeze
  VALIDATABLE_DELEGATOR_ATTRIBUTES_HASH = {}
  VALIDATABLE_DELEGATOR_ATTRIBUTES.each do |field|
    VALIDATABLE_DELEGATOR_ATTRIBUTES_HASH[field] = true
  end

  AVATAR_EXT = %w(.jpg .jpeg .jpe .png).freeze
  AVATAR_CONTENT = {
    '.jpg' => 'image/jpeg',
    '.jpeg' => 'image/jpeg',
    '.jpe' => 'image/jpeg',
    '.png' => 'image/png'
  }.freeze

  ACTIVITY_TYPES = %w(tickets archived_tickets).freeze
  LOAD_OBJECT_EXCEPT = %w[bulk_delete export export_details].freeze

  FIELD_MAPPINGS = {
    :"company_domains.base" => :domains,
    :"company_domains.domain" => :domains,
    attachment_ids: :avatar_id
  }.freeze

  SIDE_LOADING = %w(contacts_count).freeze
  ATTRIBUTES_TO_BE_STRIPPED = %w(name description note domains custom_fields).freeze
  MAX_ACTIVITIES_COUNT = 10
  MAX_ARCHIVE_TICKETS_ACTIVITIES_COUNT = 30
  ALLOWED_AVATAR_SIZE = 5 * 1024 * 1024
  DELEGATOR_CLASS = 'CompanyDelegator'.freeze
end.freeze
