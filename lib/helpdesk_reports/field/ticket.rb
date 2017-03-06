module HelpdeskReports::Field::Ticket
  include HelpdeskReports::Helper::PlanConstraints
  include HelpdeskReports::Helper::FilterFields
  # Filter data for reports, Check template at the end of file
 

  def get_default_choices(field)  
    case field.to_sym
    when :status
      Helpdesk::TicketStatus.status_names_from_cache(Account.current)
    when :ticket_type
      Account.current.ticket_types_from_cache.collect { |tt| [tt.id, tt.value] }
    when :source
      TicketConstants.source_list.sort
    when :priority
      TicketConstants.priority_list.sort
    when :agent_id
      Account.current.agents_details_from_cache.collect { |au| [au.id, au.name] }
    when :group_id
      Account.current.groups_from_cache.collect { |g| [g.id, g.name]}
    when :product_id
      Account.current.products.collect {|p| [p.id, p.name]}
    when :company_id
      Account.current.companies_from_cache.collect { |au| [au.id, au.name] }
    when :tags
      Account.current.tags_from_cache.collect { |au| [au.id, CGI.escapeHTML(au.name)] }
    else
      []
    end
  end

end
