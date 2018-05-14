module ArchiveTicketEs

  def archive_tickets_from_es(params)
    
    should_fetch_tickets = true
    total_records = []
    params[:original_query] = params[:query]
    add_display_id_filter_to_query!(params, 1)
    
    while should_fetch_tickets
      error, records_from_es = results(params)
      yield error, records_from_es
      if error.blank? && more_results_present?(records_from_es.total_entries) 
        next_ticket_id = records_from_es.last.display_id + 1 #ES always return >= results. Thus adding + 1 to avoid duplication
        add_display_id_filter_to_query!(params, next_ticket_id)
      else
        should_fetch_tickets = false 
      end
    end
  end

  def results(params)
    fq_builder = Freshquery::Builder.new.query do |builder|
      builder[:account_id]    = Account.current.id
      builder[:context]       = :search_ticket_api
      builder[:current_page]  = ApiSearchConstants::DEFAULT_PAGE
      builder[:types]         = ['archiveticket']
      builder[:es_models]     = ApiSearchConstants::ARCHIVE_TICKET_ASSOCIATIONS
      builder[:es_params]     = es_params
      builder[:query]         = params[:query]
    end
    response = fq_builder.response
    return response.errors, response.items
  end

  private
    def es_params
      es_params = { sort_by: 'display_id', sort_direction: 'asc' }
      if User.current.restricted?
        es_params[:restricted_responder_id] = User.current.id.to_i
        es_params[:restricted_group_id]     = User.current.agent_groups.map(&:group_id) if User.current.group_ticket_permission
        if Account.current.shared_ownership_enabled?
          es_params[:restricted_internal_agent_id] = User.current.id.to_i
          es_params[:restricted_internal_group_id] = User.current.agent_groups.map(&:group_id) if User.current.group_ticket_permission
        end
      end
      es_params
    end

    def add_display_id_filter_to_query!(params, display_id)
      display_id_condition = "display_id:>#{display_id}"
      params[:query] = "\"#{params[:original_query]} AND #{display_id_condition}\"" 
    end

    def more_results_present?(total_records)
      total_records > ApiSearchConstants::MAX_ITEMS_PER_PAGE  
    end
end