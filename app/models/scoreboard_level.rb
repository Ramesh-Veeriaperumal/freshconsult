class ScoreboardLevel < ActiveRecord::Base
  
  serialize :levels_data

  belongs_to :account

  LEVELS = [
    [ :beginner,      I18n.t('gamification.levels.beginner'),      100,  1 ], 
    [ :intermediate,  I18n.t('gamification.levels.intermediate'),  500,  2 ], 
    [ :pro,           I18n.t('gamification.levels.professional'), 1000, 3 ],
    [ :expert,        I18n.t('gamification.levels.expert'),       2500, 4 ],
    [ :master,        I18n.t('gamification.levels.master'),       5000, 5 ],
    [ :guru,          I18n.t('gamification.levels.guru'),        10000, 6 ] 
  ]

  LEVELS_OPTION = LEVELS.map { |i| [i[1], i[2]] }
  LEVELS_NAMES_BY_KEY = Hash[*LEVELS.map { |i| [i[2], i[1]] }.flatten]
  LEVELS_KEYS_BY_TOKEN = Hash[*LEVELS.map { |i| [i[0], i[2]] }.flatten]

end
