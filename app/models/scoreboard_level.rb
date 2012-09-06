class ScoreboardLevel < ActiveRecord::Base
  
  belongs_to :account

  LEVELS_SEED_DATA = [
    [ I18n.t('gamification.levels.beginner'),      100 ], 
    [ I18n.t('gamification.levels.intermediate'),  500 ], 
    [ I18n.t('gamification.levels.professional'), 1000 ],
    [ I18n.t('gamification.levels.expert'),       2500 ],
    [ I18n.t('gamification.levels.master'),       5000 ],
    [ I18n.t('gamification.levels.guru'),        10000 ] 
  ]

  named_scope :level_for_score, lambda { | score | { 
      :conditions => [ 'points <= ?', score ], 
      :limit => 1, 
      :order => 'points DESC' 
    } 
  }

end
