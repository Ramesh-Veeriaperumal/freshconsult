module ApiSearchConstants
  FIELDS = ['query'].freeze
  QUERY_SIZE = 512
  STRING_WITHIN_QUOTES = /\"(.*)\"/
  DEFAULT_INDEX_FIELDS = ApiConstants::DEFAULT_INDEX_FIELDS - %w( per_page ).freeze
  DEFAULT_PER_PAGE = 30
  DEFAULT_PAGE = 1
  MAX_PAGE = 10

  TICKET_DATE_FIELDS = %w( created_at updated_at due_by fr_due_by ).freeze
  TICKET_FIELDS = %w( priority status group_id type tag agent_id ).freeze | TICKET_DATE_FIELDS

  TICKET_FIELDS_REGEX = /^ff(s|_boolean|_int|_date)/
  CUSTOMER_FIELDS_REGEX = /^cf_(str|boolean|int)/
  CONTACT_FIELDS = %w( company_id twitter_id email mobile phone ).freeze
  COMPANY_FIELDS = %w( domain ).freeze
  ALLOWED_CUSTOM_FIELD_TYPES = %w( custom_text custom_number custom_checkbox custom_date custom_dropdown ).freeze

  ES_KEYS = { "fr_due_by" => "frDueBy", "type" => "ticket_type", "tag" => "tag_names", "agent_id" => "responder_id" }.freeze
  ES_OPERATORS = { "<" => "lte", ">" => "gte", "OR" => "should", "AND" => "must" }.freeze

  TICKET_ASSOCIATIONS = { 'ticket' => { model: 'Helpdesk::Ticket', associations: [ { flexifield: :flexifield_def }, :ticket_old_body, :schema_less_ticket, :flexifield] } }
  CONTACT_ASSOCIATIONS = { 'user' => { model: 'User', associations: [ :flexifield, :default_user_company ] } }
  COMPANY_ASSOCIATIONS = { 'company' => { model: 'Company', associations: [ :flexifield, :company_domains ] } }
  
  # email is not supported in tickets search
  # PRE_FETCH = { ticket: { email: :requester_id } }.freeze
end.freeze
