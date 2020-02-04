class HyperTrail::ActivityDataTransformer::TicketDataTransformer < HyperTrail::ActivityDataTransformer
  ACTIVITY_TYPE = 'ticket'.freeze
  TICKET_PRELOAD_OPTIONS = [:tags, :ticket_states, :ticket_old_body, :requester].freeze

  def activity_type
    ACTIVITY_TYPE
  end

  def collection_id
    :display_id
  end

  def load_objects(ids)
    loaded_tickets = current_account.tickets.where(display_id: ids)
                      .preload(TICKET_PRELOAD_OPTIONS)
                      .permissible(current_user)
                      .visible
    loaded_tickets_map = Hash[*loaded_tickets.map { |ticket| [ticket.display_id, ticket] }.flatten]
    loaded_tickets_map
  end

  def fetch_decorated_properties_for_object(ticket)
    TicketDecorator.new(ticket, sideload_options: ['requester']).to_timeline_hash
  end
end
