class Va::Condition
  
  attr_accessor :handler, :key, :operator
  
  QUERY_COLUMNS = {
    
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
    #method_defined? doesn't work..
    return "helpdesk_tickets.#{key}" if Helpdesk::Ticket.column_names.include? key
    
    key
  end
  
end
