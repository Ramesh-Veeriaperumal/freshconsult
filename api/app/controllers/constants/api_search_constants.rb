module ApiSearchConstants
  FIELDS = ['query'].freeze
  QUERY_SIZE = 512
  STRING_WITHIN_QUOTES = /\"(.*)\"/
  DEFAULT_INDEX_FIELDS = ApiConstants::DEFAULT_INDEX_FIELDS - %w(per_page).freeze
  DEFAULT_PER_PAGE = 30
  DEFAULT_PAGE = 1
  MAX_PAGE = 10
  
  TICKET_ASSOCIATIONS = { 'ticket' => { model: 'Helpdesk::Ticket', associations: [{ flexifield: :flexifield_def }, :ticket_old_body, :schema_less_ticket, :flexifield] } }.freeze
  CONTACT_ASSOCIATIONS = { 'user' => { model: 'User', associations: [:flexifield, :default_user_company] } }.freeze
  COMPANY_ASSOCIATIONS = { 'company' => { model: 'Company', associations: [:flexifield, :company_domains] } }.freeze
end.freeze
