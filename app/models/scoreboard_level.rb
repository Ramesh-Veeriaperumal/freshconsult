class ScoreboardLevel < ActiveRecord::Base
  
  belongs_to :account

  LEVELS_SEED_DATA = [
    [ I18n.t('gamification.levels.beginner'),       100 ], 
    [ I18n.t('gamification.levels.intermediate'),  2500 ], 
    [ I18n.t('gamification.levels.professional'), 10000 ],
    [ I18n.t('gamification.levels.expert'),       25000 ],
    [ I18n.t('gamification.levels.master'),       50000 ],
    [ I18n.t('gamification.levels.guru'),        100000 ] 
  ]

  named_scope :level_for_score, lambda { | score | { 
      :conditions => [ 'points <= ?', score ], 
      :limit => 1, 
      :order => 'points DESC' 
    } 
  }

  named_scope :next_level_for_points, lambda { |points| {
      :conditions => [ 'points > ?', points ],
      :limit => 1,
      :order => 'points ASC'
    }
  }

  named_scope :level_up_for, lambda { |level| {
      :conditions => ['id = ? or points > ?', level, level.points ],
      :order => 'points ASC'
    } if level
  }

end
