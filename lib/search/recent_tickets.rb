class Search::RecentTickets < Search::RecentStore

  HELPDESK_TICKET_PATH = "/helpdesk/tickets/%{display_id}"
  HELPDESK_ARCHIVED_TICKET_PATH = "/helpdesk/tickets/archived/%{display_id}"
  
  def initialize(recent_item=nil)
    @key = redis_persistent_recent_tickets_key
    super
  end

  def recent
    recent_tickets = []
    recent_ticket_ids = super
    return recent_tickets if recent_ticket_ids.length == 0
    Sharding.run_on_slave do
      tickets = Account.current.tickets.where(:display_id => recent_ticket_ids).select('helpdesk_tickets.display_id, helpdesk_tickets.subject').order("field(display_id, #{recent_ticket_ids.join(',')})")
      recent_tickets = tickets.inject([]) do |result, ticket|
        result << {
          :displayId => ticket.display_id,
          :subject => ticket.subject,
          :path => HELPDESK_TICKET_PATH % { :display_id => ticket.display_id}
        }
      end
      unless recent_tickets.length == recent_ticket_ids.length
        # There are some archive tickets
        archive_tickets = Account.current.archive_tickets.where(:display_id => recent_ticket_ids).select('archive_tickets.display_id, archive_tickets.subject').order("field(display_id, #{recent_ticket_ids.join(',')})")
        recent_tickets = archive_tickets.inject(recent_tickets) do |result, ticket|
          result << {
            :displayId => ticket.display_id,
            :subject => ticket.subject,
            :path => HELPDESK_ARCHIVED_TICKET_PATH % { :display_id => ticket.display_id}
          }
        end
      end            
    end    
    recent_tickets
  end


  private

  def redis_persistent_recent_tickets_key     
    PERSISTENT_RECENT_TICKETS % { :account_id => Account.current.id, :user_id => User.current.id }
  end

end