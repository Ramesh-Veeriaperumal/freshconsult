module ApiSearchConstants
  FIELDS = ['query'].freeze
  QUERY_SIZE = 512
  STRING_WITHIN_QUOTES = /\"(.*)\"/
  DEFAULT_INDEX_FIELDS = ApiConstants::DEFAULT_INDEX_FIELDS - %w( per_page ).freeze
  DEFAULT_PER_PAGE = 30
  DEFAULT_PAGE = 1
  MAX_PAGE = 10

  TICKET_FIELDS = %w( priority status group_id ).freeze
  TICKET_FIELDS_REGEX = /^ff(s|_boolean|_int)/
  CUSTOMER_FIELDS_REGEX = /^cf_(str|boolean|int)/
  CONTACT_FIELDS = %w( company_id twitter_id email mobile phone ).freeze
  COMPANY_FIELDS = %w( domain ).freeze
  ALLOWED_CUSTOM_FIELD_TYPES = %w( custom_text custom_number custom_checkbox ).freeze

  ES_KEYS = { email: :emails, company_id: :company_ids, domain: :domains }.freeze

  TICKET_ASSOCIATIONS = { 'ticket' => { model: 'Helpdesk::Ticket', associations: [ { flexifield: :flexifield_def }, :ticket_old_body, :schema_less_ticket, :flexifield] } }
  CONTACT_ASSOCIATIONS = { 'user' => { model: 'User', associations: [ :flexifield, :default_user_company ] } }
  COMPANY_ASSOCIATIONS = { 'company' => { model: 'Company', associations: [ :flexifield, :company_domains ] } }
  
  # email is not supported in tickets search
  # PRE_FETCH = { ticket: { email: :requester_id } }.freeze
end.freeze
