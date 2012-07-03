class ScoreboardRating < ActiveRecord::Base
  
  #resolution-speed - score_trigger
  FAST_RESOLUTION = 1
  ON_TIME_RESOLUTION = 2
  LATE_RESOLUTION = 3
  
  #bonus-points - score_trigger
  FIRST_CALL_RESOLUTION  = 101
  HAPPY_CUSTOMER = 102
  UNHAPPY_CUSTOMER = 103

  belongs_to :account
  
  # We are not doing any validation here, whether the ticket is actually resolved or
  # resolved_at is not null and stuffs like that.
  # It is helpdesk module's responsibility.
  def self.resolution_speed(ticket)
    
    resolved_at = ticket.ticket_states.resolved_at
    inbound_count = ticket.ticket_states.inbound_count

    (resolved_at < 1.hour.since(ticket.created_at)) ? FAST_RESOLUTION : ( (resolved_at < 
      ticket.due_by) ? ON_TIME_RESOLUTION : LATE_RESOLUTION )
  end
end
