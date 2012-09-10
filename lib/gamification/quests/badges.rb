module Gamification
  module Quests
    module Badges
      
      BADGES = [
        { :name => "Newbie", :desc => "Awarded for your first check in", 
          :classname => "badges-call", :id => 1 },
        { :name => "Adventurer", :desc => "Check in to 10 different venues", 
          :classname => "badges-elephant", :id => 2 },
        { :name => "Explorer", :desc => "Check in to 25 different venues", 
          :classname => "badges-fb", :id => 3 },
        { :name => "Superstar", :desc => "Check in to 50 different venues.", 
          :classname => "badges-fcr", :id => 4 },
        { :name => "Bender", :desc => "Check in 4 nights in a row.", 
          :classname => "badges-forum", :id => 5 },
        { :name => "Crunked", :desc => "Check in 4 times in a night.", 
          :classname => "badges-love", :id => 6 },
        { :name => "Local", :desc => "Check in at the same place 3x in a week.", 
          :classname => "badges-priority", :id => 7 },
        { :name => "Superuser", :desc => "Check in 30 times in a month.", 
          :classname => "badges-settings", :id => 8 },
        { :name => "Jetsetter", :desc => "Check in to 5 airports.", 
          :classname => "badges-shooter", :id => 9 },
        { :name => "Super Mayor", :desc => "Be the Mayor of 10 venues at once.", 
          :classname => "badges-smiley", :id => 10 },
        { :name => "Blah..", :desc => "Be the Mayor of 10 venues at once.", 
          :classname => "badges-time", :id => 11 },
        { :name => "Super Trophy", :desc => "Be the Mayor of 10 venues at once.", 
          :classname => "badges-trophy", :id => 12 }
      ]

      BADGES_BY_ID = Hash[*BADGES.map { |badge| [badge[:id], badge] }.flatten] 
    end
  end
end
