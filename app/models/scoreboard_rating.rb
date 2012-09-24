class ScoreboardRating < ActiveRecord::Base
  
  include Gamification::Scoreboard::Constants
 
  belongs_to_account

  attr_protected  :account_id
  
  # We are not doing any validation here, whether the ticket is actually resolved or
  # resolved_at is not null and stuffs like that.
  # It is helpdesk module's responsibility.
  def self.resolution_speed(ticket, resolved_at)
    
    resolved_at = Time.zone.parse(resolved_at.to_s)
    inbound_count = ticket.ticket_states.inbound_count

    (resolved_at < 1.hour.since(ticket.created_at)) ? FAST_RESOLUTION : ( (resolved_at < 
      ticket.due_by) ? ON_TIME_RESOLUTION : LATE_RESOLUTION )
  end

  def resolution_name
    RESOLUTION_TOKEN_BY_KEY[resolution_speed]
  end

end
