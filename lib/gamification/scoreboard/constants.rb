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

      #Quest-points - score_trigger
      TICKET_QUEST = 201
      SOLUTION_QUEST = 202
      FORUM_QUEST = 203

      #Admin-config - levels_to_agents
      AGENT_LEVEL_UP = 301

      RESOLUTION = [
        [ :fast_resolution,          FAST_RESOLUTION ],
        [ :ontime_resolution,        ON_TIME_RESOLUTION ],
        [ :late_resolution,          LATE_RESOLUTION ],
        [ :firstcall_resolution,     FIRST_CALL_RESOLUTION ],
        [ :happy_customer,           HAPPY_CUSTOMER ],
        [ :unhappy_customer,         UNHAPPY_CUSTOMER ]
      ]
      
      RESOLUTION_OPTIONS = RESOLUTION.map { |i| [i[1], i[0]] }
      RESOLUTION_TOKEN_BY_KEY = Hash[*RESOLUTION.map { |i| [i[1], i[0]] }.flatten]

      TICKET_CLOSURE = [  FAST_RESOLUTION, ON_TIME_RESOLUTION, LATE_RESOLUTION, FIRST_CALL_RESOLUTION ]
    end
  end
end
