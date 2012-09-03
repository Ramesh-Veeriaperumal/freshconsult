class ScoreboardRating < ActiveRecord::Base
  
  #resolution-speed - score_trigger
  FAST_RESOLUTION = 1
  ON_TIME_RESOLUTION = 2
  LATE_RESOLUTION = 3
  
  #bonus-points - score_trigger
  FIRST_CALL_RESOLUTION  = 101
  HAPPY_CUSTOMER = 102
  UNHAPPY_CUSTOMER = 103

  RESOLUTION = [
    [ :fast_resolution,      I18n.t('admin.gamification.gamification_settings.label_fast_resolution'),         1 ],
    [ :ontime_resolution,    I18n.t('admin.gamification.gamification_settings.label_ontime_resolution'),       2 ],
    [ :late_resolution,      I18n.t('admin.gamification.gamification_settings.label_late_resolution'),         3 ],
    [ :firstcall_resolution, I18n.t('admin.gamification.gamification_settings.label_firstcall_resolution'),    101 ],
    [ :happy_customer,       I18n.t('admin.gamification.gamification_settings.label_happy_customer'),          102 ],
    [ :unhappy_customer,     I18n.t('admin.gamification.gamification_settings.label_unhappy_customer'),        103 ]
  ]

  RESOLUTION_OPTIONS = RESOLUTION.map { |i| [i[1], i[2]] }
  RESOLUTION_NAMES_BY_KEY = Hash[*RESOLUTION.map { |i| [i[2], i[1]] }.flatten]
  RESOLUTION_KEYS_BY_TOKEN = Hash[*RESOLUTION.map { |i| [i[0], i[2]] }.flatten]
 
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

  def resolution_name
    RESOLUTION_NAMES_BY_KEY[resolution_speed]
  end
end
