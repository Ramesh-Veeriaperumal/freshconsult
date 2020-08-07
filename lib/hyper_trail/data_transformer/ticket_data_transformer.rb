class HyperTrail::DataTransformer::TicketDataTransformer < HyperTrail::DataTransformer::ActivityDataTransformer
  ACTIVITY_TYPE = 'ticket'.freeze
  UNIQUE_ID = 'display_id'.freeze
  TICKET_PRELOAD_OPTIONS = [:tags, :ticket_states, :ticket_body, :requester].freeze

  def activity_type
    ACTIVITY_TYPE
  end

  def unique_id
    UNIQUE_ID
  end

  def transform
    loaded_tickets = load_objects_from_db
    loaded_tickets.each do |ticket|
      ticket_object = data_map[ticket.display_id]
      next if ticket_object.blank?

      ticket_object.valid = true
      activity = ticket_object.activity
      activity[:activity][:context] = fetch_decorated_properties_for_object(ticket)
      activity[:activity][:timestamp] = ticket.created_at.try(:utc)
      ticket_object.activity = activity
    end
  end

  private

    def load_objects_from_db
      current_account.tickets.where(display_id: object_ids)
                     .preload(TICKET_PRELOAD_OPTIONS)
                     .permissible(current_user)
                     .visible
    end

    def fetch_decorated_properties_for_object(ticket)
      TicketDecorator.new(ticket, sideload_options: ['requester']).to_timeline_hash
    end
end
