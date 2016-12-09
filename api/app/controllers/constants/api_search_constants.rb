module ApiSearchConstants
  FIELDS = ['query'].freeze
  QUERY_SIZE = 512
  STRING_WITHIN_QUOTES = /\"(.*)\"/

  TICKET_FIELDS = %w( priority status group_id requester_id ).freeze
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
