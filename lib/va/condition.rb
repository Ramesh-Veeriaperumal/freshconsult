class Va::Condition
  
  attr_accessor :handler, :key, :operator
  
  QUERY_COLUMNS = {
    'subject_or_description'  => [ 'helpdesk_tickets.subject', 'helpdesk_tickets.description' ],
    'from_email'              => 'users.email',
    'contact_name'            => 'users.name',
    'company_name'            => 'customers.name'
  }
  
  def initialize(rule, account)
    @key, @operator = rule[:name], rule[:operator] #by Shan hack must spelling mistake in criteria
    handler_class = VAConfig.handler @key.to_sym, account
    @handler = handler_class.constantize.new(self, rule)
  end
  
  def matches(evaluate_on)
    handler.matches(evaluate_on)
  end
  
  def filter_query
    handler.filter_query
  end
  
  def db_column
    return QUERY_COLUMNS[key] if QUERY_COLUMNS.key? key
    
    #method_defined? doesn't work..
    return "helpdesk_tickets.#{key}" if Helpdesk::Ticket.column_names.include? key
    return "helpdesk_ticket_states.#{key}" if Helpdesk::TicketState.column_names.include? key
    
    #Following things will have a high penalty due to higher number of db queries.
    #Need to optimize.
    "flexifields.#{FlexifieldDefEntry.ticket_db_column key}"
  end
  
end
