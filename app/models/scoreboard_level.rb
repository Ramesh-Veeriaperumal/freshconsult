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

  scope :level_for_score, lambda { | score | { 
      :conditions => [ 'points <= ?', score ], 
      :limit => 1, 
      :order => 'points DESC' 
    } 
  }

  scope :next_level_for_points, lambda { |points| {
      :conditions => [ 'points > ?', points ],
      :limit => 1,
      :order => 'points ASC'
    }
  }

  scope :level_up_for, lambda { |level| {
      :conditions => ['id = ? or points > ?', level, level.points ],
      :order => 'points ASC'
    } if level
  }

  scope :least_points, lambda {{ :order => 'points ASC', :limit => 1 }}

end
