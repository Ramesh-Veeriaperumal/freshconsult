module Gamification
  module Quests
    module Constants
      include Gamification::Scoreboard::Constants

      GAME_TYPES = [
        [ :none,     "--- Click to Select ---",  "",              0 ],
        [ :ticket,   "Resolving Tickets",        TICKET_QUEST,    1 ], 
        [ :solution, "Publishing Solutions",     SOLUTION_QUEST,  2 ], 
        [ :forum,    "Contribute in Forums",     FORUM_QUEST,     3 ]
      ]

      GAME_TYPE_OPTIONS = GAME_TYPES.map { |i| [i[1], i[3]] }
      GAME_TYPE_KEYS_BY_TOKEN = Hash[*GAME_TYPES.map { |i| [i[0], i[3]] }.flatten]
      GAME_TYPE_TOKENS_BY_KEY = Hash[*GAME_TYPES.map { |i| [i[3], i[0]] }.flatten]
      QUEST_SCORE_TRIGGERS_BY_ID = Hash[*GAME_TYPES.map { |i| [i[3], i[2]] }.flatten]

      
      QUEST_TIME = [
          [ :any_time,      "Any time",  "",       1 ],
          [ :one_day,       "1 day",     1.day,    2 ],
          [ :two_days,      "2 days",    2.days,   3 ],
          [ :one_week,      "1 week",    1.week,   4 ],
          [ :two_weeks,     "2 weeks",   2.weeks,  5 ],
          [ :one_month,     "1 month",   1.month,  6 ],
          [ :one_year,      "1 year",    1.year,   7 ]
      ]
      
      QUEST_TIME_BY_KEY = Hash[*QUEST_TIME.map { |i| [i[3], i[1]] }.flatten] 
      QUEST_TIME_SPAN_BY_KEY = Hash[*QUEST_TIME.map { |i| [i[3], i[2]] }.flatten] 

      FORUM_QUEST_MODE = [
          [ :create, "Create", 1 ],
          [ :answer, "Answer", 2 ]
      ]

      FORUM_QUEST_MODE_BY_KEY = Hash[*FORUM_QUEST_MODE.map { |i| [i[2], i[1]] }.flatten]
      FORUM_QUEST_MODE_BY_TOKEN = Hash[*FORUM_QUEST_MODE.map { |i| [i[0], i[2]] }.flatten]
      
      QUEST_BASE_CRITERIA = {
        :ticket   =>  { :disp_name => "Resolve ##questvalue## Tickets within ##questtime##", 
                        :input => ["questvalue","questtime"], :questtime => QUEST_TIME_BY_KEY.sort },
        :solution =>  { :disp_name => "Create ##questvalue## Knowledgebase article within ##questtime##", 
                        :input => ["questvalue","questtime"], :questtime => QUEST_TIME_BY_KEY.sort },
        :forum    =>  { :disp_name => "##questmode## ##questvalue## Forum posts within ##questtime##", 
                        :input => ["questvalue","questmode","questtime"], 
                        :questmode => FORUM_QUEST_MODE_BY_KEY.sort, :questtime => QUEST_TIME_BY_KEY.sort }
      }

      QUEST_TIME_COLUMNS = {
        :ticket => 'helpdesk_ticket_states.resolved_at',
        :solution => 'solution_articles.created_at',
      }

    end
  end
end
