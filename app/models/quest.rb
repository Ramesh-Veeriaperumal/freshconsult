class Quest < ActiveRecord::Base
  include Gamification::Quests::Constants
  
  belongs_to :account

  serialize :award_data
  serialize :filter_data
  serialize :quest_data
  
  named_scope :disabled, :conditions => { :active => false }
  named_scope :enabled, :conditions => { :active => true }

  named_scope :ticket_quests, :conditions => {
    :questtype => GAME_TYPE_KEYS_BY_TOKEN[:quest_ticket],
  }

  named_scope :forum_quests, :conditions => {
    :questtype => GAME_TYPE_KEYS_BY_TOKEN[:quest_forum],
  }

  named_scope :solution_quests, :conditions => {
    :questtype => GAME_TYPE_KEYS_BY_TOKEN[:quest_solution],
  }

  named_scope :survey_quests, :conditions => {
    :questtype => GAME_TYPE_KEYS_BY_TOKEN[:quest_survey],
  }

  def after_find
    deserialize_them
  end

  def deserialize_them
    award_data.each do |f|
      f.symbolize_keys!
    end unless !award_data
    
    filter_data.each do |f|
      f.symbolize_keys!
    end unless !filter_data

    quest_data.each do |f|
      f.symbolize_keys!
    end unless !quest_data
  end
  
end
