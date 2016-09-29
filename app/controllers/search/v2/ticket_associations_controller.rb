class Search::V2::TicketAssociationsController < Search::V2::TicketsController
  
  def index
    search_users if (@search_field == 'requester')

    @search_context = case @search_field
      when 'display_id'
        :assoc_tickets_display_id
      when 'subject'
        :assoc_tickets_subject
      when 'requester'
        :assoc_tickets_requester
    end
    
    search(esv2_agent_models)
  end
  
  def recent_trackers
    @search_context   = :assoc_recent_trackers
    @recent_trackers  = true
    
    search(esv2_agent_models)
  end
  
  private
  
    def construct_es_params
      super.tap do |es_params|
        es_params[:association_type]  = TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:tracker]
        es_params[:exclude_status]    = [
                                          Helpdesk::Ticketfields::TicketStatus::CLOSED, Helpdesk::Ticketfields::TicketStatus::RESOLVED
                                        ] if @recent_trackers
      end
    end
  
    # ESType - [model, associations] mapping
    # Needed for loading records from DB
    #
    def esv2_agent_models
      @@esv2_assoc_ticket ||= {
        'ticket'  => { model: 'Helpdesk::Ticket', associations: [ :requester, :ticket_status ] }
      }
    end
end