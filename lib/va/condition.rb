class Va::Condition
  
  attr_accessor :handler, :key, :operator, :action_performed
  

  DISPATCHER_COLUMNS = {
    'to_email'                => 'to_emails'
  }

  QUERY_COLUMNS = {
    'subject_or_description'  => [ 'helpdesk_tickets.subject', 'helpdesk_tickets.description' ],
    'from_email'              => 'users.email',
    'contact_name'            => 'users.name',
    'company_name'            => 'customers.name',
    'st_survey_rating'        => 'helpdesk_schema_less_tickets.int_tc01',
    'folder_id'               => 'solution_articles.folder_id',
    'thumbs_up'               => 'solution_articles.thumbs_up',
    'forum_id'                => 'topics.forum_id',
    'user_votes'              => 'topics.user_votes'
  }
  
  def initialize(rule, account)
    @key, @operator, @action_performed = rule[:name], rule[:operator], rule[:action_performed] #by Shan hack must spelling mistake in criteria
    handler_class = VAConfig.handler @key.to_sym, account
    @handler = handler_class.constantize.new(self, rule)
  end
  
  def matches(evaluate_on, actions=nil)
    if actions.blank?
      handler.matches(evaluate_on) 
    elsif action_matches?(evaluate_on, actions) 
      handler.matches(evaluate_on)
    end
  end
  
  def dispatcher_key
    return (DISPATCHER_COLUMNS.key?(key)) ? DISPATCHER_COLUMNS[key] : key
  end

  def filter_query
    handler.filter_query
  end
  
  def db_column
    return QUERY_COLUMNS[key] if QUERY_COLUMNS.key? key

    #method_defined? doesn't work..
    return "helpdesk_schema_less_tickets.#{dispatcher_key}" if Helpdesk::SchemaLessTicket.column_names.include? dispatcher_key
    return "helpdesk_tickets.#{key}" if Helpdesk::Ticket.column_names.include? key
    return "helpdesk_ticket_states.#{key}" if Helpdesk::TicketState.column_names.include? key
    
    #Following things will have a high penalty due to higher number of db queries.
    #Need to optimize.
    "flexifields.#{FlexifieldDefEntry.ticket_db_column key}"
  end

  private
    def action_matches?(evaluate_on, performed_actions)
      expected_action = @action_performed[:action]
      RAILS_DEFAULT_LOGGER.debug "Inside action_matches check: expected_action #{expected_action} performed_actions #{performed_actions} action_performed #{@action_performed.inspect}"
      performed_actions.include?(expected_action) && @action_performed[:entity] == evaluate_on.class.name
    end
end
