class ScoreboardLevel < ActiveRecord::Base
  self.primary_key = :id
  
  belongs_to :account

  LEVELS_SEED_DATA = [
    [ I18n.t('gamification.levels.beginner'),       100 ], 
    [ I18n.t('gamification.levels.intermediate'),  2500 ], 
    [ I18n.t('gamification.levels.professional'), 10000 ],
    [ I18n.t('gamification.levels.expert'),       25000 ],
    [ I18n.t('gamification.levels.master'),       50000 ],
    [ I18n.t('gamification.levels.guru'),        100000 ] 
  ]

  scope :level_for_score, -> (score) {
    where([ 'points <= ?', score ]).
    order('points DESC').
    limit(1)
  }

  scope :next_level_for_points, -> (points) {
    where([ 'points > ?', points ]).
    order('points ASC').
    limit(1)
  }

  scope :level_up_for, -> (level) {
    where(['id = ? or points > ?', level, level.points ]).
    order('points ASC') if level
  }

  scope :least_points, -> { order('points ASC').limit(1) }

end
