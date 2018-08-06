module Segments::FilterDataConstants
  DEFAULT_FIELD = 'default'.freeze
  CUSTOM_FIELD = 'custom_field'.freeze
  STRING_FIELD = 'cf_str'.freeze
  CONTACT = 'contacts'.freeze

  ALLOWED_CUSTOM_FIELDS = ['cf_str', 'cf_int', 'cf_boolean'].freeze # to support date field add cf_date
  ALLOWED_CUSTOM_FIELD_TYPES     = ['custom_dropdown', 'custom_number', 'custom_checkbox'].freeze
  ALLOWED_CONTACT_DEFAULT_FIELDS = ['tag_names', 'time_zone', 'company_name', 'twitter_id', 'created_at'].freeze
  ALLOWED_COMPANY_DEFAULT_FIELDS = ['created_at'].freeze
end
