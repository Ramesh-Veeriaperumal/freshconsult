module Gamification
  module Scoreboard
    module Constants
	
      #resolution-speed - score_trigger
      FAST_RESOLUTION = 1
      ON_TIME_RESOLUTION = 2
      LATE_RESOLUTION = 3
      
      #bonus-points - score_trigger
      FIRST_CALL_RESOLUTION  = 101
      HAPPY_CUSTOMER = 102
      UNHAPPY_CUSTOMER = 103

      RESOLUTION = [
        [ :fast_resolution,     I18n.t('admin.gamification.gamification_settings.label_fast_resolution'),         FAST_RESOLUTION ],
        [ :ontime_resolution,   I18n.t('admin.gamification.gamification_settings.label_ontime_resolution'),     ON_TIME_RESOLUTION ],
        [ :late_resolution,     I18n.t('admin.gamification.gamification_settings.label_late_resolution'),         LATE_RESOLUTION ],
        [ :firstcall_resolution,I18n.t('admin.gamification.gamification_settings.label_firstcall_resolution'),    FIRST_CALL_RESOLUTION ],
        [ :happy_customer,      I18n.t('admin.gamification.gamification_settings.label_happy_customer'),      HAPPY_CUSTOMER ],
        [ :unhappy_customer,    I18n.t('admin.gamification.gamification_settings.label_unhappy_customer'),  UNHAPPY_CUSTOMER ]
      ]
      
      RESOLUTION_OPTIONS = RESOLUTION.map { |i| [i[1], i[2]] }
      RESOLUTION_NAMES_BY_KEY = Hash[*RESOLUTION.map { |i| [i[2], i[1]] }.flatten]

      TICKET_CLOSURE = [  FAST_RESOLUTION, ON_TIME_RESOLUTION, LATE_RESOLUTION, FIRST_CALL_RESOLUTION ]
    end
  end
end
