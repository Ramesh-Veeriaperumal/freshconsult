module Gamification
  module Quests
    module Badges
      
      BADGES = [
        { :name => "Newbie", :classname => "badges-call", :id => 1 },
        { :name => "Adventurer", :classname => "badges-elephant", :id => 2 },
        { :name => "Explorer", :classname => "badges-fb", :id => 3 },
        { :name => "Superstar", :classname => "badges-fcr", :id => 4 },
        { :name => "Bender", :classname => "badges-forum", :id => 5 },
        { :name => "Crunked", :classname => "badges-love", :id => 6 },
        { :name => "Local", :classname => "badges-priority", :id => 7 },
        { :name => "Superuser", :classname => "badges-settings", :id => 8 },
        { :name => "Jetsetter", :classname => "badges-shooter", :id => 9 },
        { :name => "Super Mayor", :classname => "badges-smiley", :id => 10 },
        { :name => "Time saver", :classname => "badges-time", :id => 11 },
        { :name => "Super Trophy", :classname => "badges-trophy", :id => 12 },
        { :name => "Comment hero", :classname => "badges-forum-comment", :id => 13 },
        { :name => "Winner", :classname => "badges-winner", :id => 14 },
        { :name => "Money", :classname => "badges-money", :id => 15 },
        { :name => "Keen resolver", :classname => "badges-glasses", :id => 16 },
        { :name => "Solution binder", :classname => "badges-closed-book", :id => 17 },
        { :name => "Experiment", :classname => "badges-experiment", :id => 18 },
        { :name => "Chart", :classname => "badges-chart", :id => 19 },
        { :name => "Cake", :classname => "badges-cake", :id => 20 },
        { :name => "Martini", :classname => "badges-martini", :id => 21 },
        { :name => "Rocket", :classname => "badges-rocket", :id => 22 },
        { :name => "Sailor", :classname => "badges-sailor", :id => 23 },
        { :name => "Spade", :classname => "badges-spade", :id => 24 },
        { :name => "Gamer", :classname => "badges-gamer", :id => 25 },
        { :name => "Late worker", :classname => "badges-late-worker", :id => 26 },
        { :name => "The professional", :classname => "badges-the-professional", :id => 27 },
        { :name => "Traveller", :classname => "badges-traveller", :id => 28 },
        { :name => "Writer", :classname => "badges-writer", :id => 29 },
        { :name => "Performer", :classname => "badges-performer", :id => 30 },
        { :name => "Open book", :classname => "badges-open-book", :id => 31 },
        { :name => "Open box", :classname => "badges-open-box", :id => 32 },
        { :name => "Radiation", :classname => "badges-radiation", :id => 33 },
        { :name => "Player", :classname => "badges-player", :id => 34 },
        { :name => "Messenger", :classname => "badges-messenger", :id => 35 },
        { :name => "Diamond", :classname => "badges-diamond", :id => 36 },
        { :name => "Scribe", :classname => "badges-scribe", :id => 37 },
        { :name => "Clover", :classname => "badges-clover", :id => 38 },
        { :name => "Joystick", :classname => "badges-joystick", :id => 39 },
        { :name => "Lamp", :classname => "badges-lamp", :id => 40 },
        { :name => "Flag", :classname => "badges-flag", :id => 41 },
        { :name => "Coffee", :classname => "badges-coffee", :id => 42 },
        { :name => "Business man", :classname => "badges-business-man", :id => 43 },
        { :name => "Artist", :classname => "badges-artist", :id => 44 },
        { :name => "Calendar", :classname => "badges-calendar", :id => 45 }

      ]

      BADGES_BY_ID = Hash[*BADGES.map { |badge| [badge[:id], badge] }.flatten] 
      BADGES_BY_CLASS = Hash[*BADGES.map { |badge| [badge[:classname], badge] }.flatten] 
    end
  end
end
