module Ember::ContactConstants
  include ContactConstants
  HASH_FIELDS = %w(company custom_fields).freeze
  ALLOWED_OTHER_COMPANIES_FIELDS = %w(id name view_all_tickets).freeze
  COMPLEX_FIELDS = ARRAY_FIELDS | HASH_FIELDS
  CONTACT_FIELDS = %w(active address avatar avatar_id view_all_tickets company_id description
                      email job_title language mobile name other_companies facebook_id
                      other_emails phone time_zone twitter_id unique_external_id).freeze |
                   ARRAY_FIELDS | HASH_FIELDS |
                   ['other_companies' => ALLOWED_OTHER_COMPANIES_FIELDS]
  VALIDATION_CLASS = 'Ember::ContactValidation'.freeze
  DELEGATOR_CLASS = 'ContactDelegator'.freeze
end.freeze
