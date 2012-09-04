class Quest < ActiveRecord::Base
  
  belongs_to :account

  serialize :award_data
  serialize :filter_data
  serialize :quest_data
  
  GAME_TYPE = [
    [ :quest_none,     "--- Click to Select ---",  -1],
    [ :quest_ticket,   "Tickets",     0 ], 
    [ :quest_solution, "Solutions",   1 ], 
    [ :quest_forum,    "Forums",      2 ],
    [ :quest_survey,   "Surveys",     3 ],
  ]

  GAME_TYPE_OPTIONS = GAME_TYPE.map { |i| [i[1], i[2]] }
  GAME_TYPE_NAMES_BY_KEY = Hash[*GAME_TYPE.map { |i| [i[2], i[1]] }.flatten] 
  GAME_TYPE_KEYS_BY_TOKEN = Hash[*GAME_TYPE.map { |i| [i[0], i[2]] }.flatten]

  BADGES_DATA = [
    { :name => "Newbie", :desc => "Awarded for your first check in", :classname => "badges-call" },
    { :name => "Adventurer", :desc => "Check in to 10 different venues", :classname => "badges-elephant" },
    { :name => "Explorer", :desc => "Check in to 25 different venues", :classname => "badges-fb" },
    { :name => "Superstar", :desc => "Check in to 50 different venues.", :classname => "badges-fcr" },
    { :name => "Bender", :desc => "Check in 4 nights in a row.", :classname => "badges-forum" },
    { :name => "Crunked", :desc => "Check in 4 times in a night.", :classname => "badges-love" },
    { :name => "Local", :desc => "Check in at the same place 3x in a week.", :classname => "badges-priority" },
    { :name => "Superuser", :desc => "Check in 30 times in a month.", :classname => "badges-settings" },
    { :name => "Jetsetter", :desc => "Check in to 5 airports.", :classname => "badges-shooter" },
    { :name => "Super Mayor", :desc => "Be the Mayor of 10 venues at once.", :classname => "badges-smiley" },
    { :name => "Blah..", :desc => "Be the Mayor of 10 venues at once.", :classname => "badges-time" },
    { :name => "Super Trophy", :desc => "Be the Mayor of 10 venues at once.", :classname => "badges-trophy" }
  ]

  BADGES_DATA_OPTIONS = BADGES_DATA.map { |i| [i[2], i[1]] }

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
