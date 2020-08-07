module ApiSearchConstants
  FIELDS = ['query'].freeze
  DEFAULT_INDEX_FIELDS = ApiConstants::DEFAULT_INDEX_FIELDS - %w(per_page).freeze
  DEFAULT_PAGE = 1
  MAX_PAGE = 10
  MAX_ITEMS_PER_PAGE = 30
  TICKET_ASSOCIATIONS = { 'ticket' => { model: 'Helpdesk::Ticket', associations: [{ flexifield: :flexifield_def }, :ticket_body, :schema_less_ticket, :flexifield, :tags] } }.freeze
  CONTACT_ASSOCIATIONS = { 'user' => { model: 'User', associations: [:flexifield, :default_user_company, :user_emails] } }.freeze
  COMPANY_ASSOCIATIONS = { 'company' => { model: 'Company', associations: [:flexifield, :company_domains] } }.freeze
  ARCHIVE_TICKET_ASSOCIATIONS = {'archiveticket' => {model: 'Helpdesk::ArchiveTicket'}}
end.freeze
