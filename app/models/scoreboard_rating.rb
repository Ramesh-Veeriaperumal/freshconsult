class ScoreboardRating < ActiveRecord::Base
  
  #resolution speed
  FAST_RESOLUTION = 1
  ON_TIME_RESOLUTION = 2
  LATE_RESOLUTION = 3
  HAPPY_CUSTOMER = 4
  
  belongs_to :account
  
  # We are not doing any validation here, whether the ticket is actually resolved or
  # resolved_at is not null and stuffs like that.
  # It is helpdesk module's responsibility.
  def self.resolution_speed(ticket)
    resolved_at = ticket.ticket_states.resolved_at
    (resolved_at < 1.hour.since(ticket.created_at)) ? FAST_RESOLUTION : ( (resolved_at < 
      ticket.due_by) ? ON_TIME_RESOLUTION : LATE_RESOLUTION )
  end
end
