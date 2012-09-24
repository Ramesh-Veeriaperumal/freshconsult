module Gamification
  module Quests
    module Badges
      
      BADGES = [
        { :name => "Support hero", :classname => "badges-call", :id => 1 },
        { :name => "Explorer", :classname => "badges-elephant", :id => 2 },
        { :name => "Social supporter", :classname => "badges-fb", :id => 3 },
        { :name => "Zeus", :classname => "badges-fcr", :id => 4 },
        { :name => "Commentor", :classname => "badges-forum", :id => 5 },
        { :name => "Heart", :classname => "badges-love", :id => 6 },
        { :name => "Local", :classname => "badges-priority", :id => 7 },
        { :name => "The fixer", :classname => "badges-settings", :id => 8 },
        { :name => "Bulls eye", :classname => "badges-shooter", :id => 9 },
        { :name => "Smile collector", :classname => "badges-smiley", :id => 10 },
        { :name => "Timekeeper", :classname => "badges-time", :id => 11 },
        { :name => "Champion", :classname => "badges-trophy", :id => 12 },
        { :name => "Super commentor", :classname => "badges-forum-comment", :id => 13 },
        { :name => "Guest of honor", :classname => "badges-winner", :id => 14 },
        { :name => "Banker", :classname => "badges-money", :id => 15 },
        { :name => "Perfectionist", :classname => "badges-glasses", :id => 16 },
        { :name => "Bibliophile", :classname => "badges-closed-book", :id => 17 },
        { :name => "Druid", :classname => "badges-experiment", :id => 18 },
        { :name => "Statistician", :classname => "badges-chart", :id => 19 },
        { :name => "Sweet-tooth", :classname => "badges-cake", :id => 20 },
        { :name => "Socialite", :classname => "badges-martini", :id => 21 },
        { :name => "Rocket scientist", :classname => "badges-rocket", :id => 22 },
        { :name => "Anchor", :classname => "badges-sailor", :id => 23 },
        { :name => "Ace", :classname => "badges-spade", :id => 24 },
        { :name => "Speed eater", :classname => "badges-gamer", :id => 25 },
        { :name => "Night owl", :classname => "badges-late-worker", :id => 26 },
        { :name => "Gentleman", :classname => "badges-the-professional", :id => 27 },
        { :name => "Traveller", :classname => "badges-traveller", :id => 28 },
        { :name => "Writer", :classname => "badges-writer", :id => 29 },
        { :name => "Performer", :classname => "badges-performer", :id => 30 },
        { :name => "Best seller", :classname => "badges-open-book", :id => 31 },
        { :name => "Tweet supporter", :classname => "badges-tweet", :id => 32 },
        { :name => "Bomber man", :classname => "badges-radiation", :id => 33 },
        { :name => "Striker", :classname => "badges-player", :id => 34 },
        { :name => "Conversationalist", :classname => "badges-messenger", :id => 35 },
        { :name => "The Diamond", :classname => "badges-diamond", :id => 36 },
        { :name => "Super writer", :classname => "badges-scribe", :id => 37 },
        { :name => "Lucky clover", :classname => "badges-clover", :id => 38 },
        { :name => "Gameboy", :classname => "badges-joystick", :id => 39 },
        { :name => "Beacon", :classname => "badges-lamp", :id => 40 },
        { :name => "Flag bearer", :classname => "badges-flag", :id => 41 },
        { :name => "Cafeholic", :classname => "badges-coffee", :id => 42 },
        { :name => "Bureaucrat", :classname => "badges-business-man", :id => 43 },
        { :name => "Artist", :classname => "badges-artist", :id => 44 },
        { :name => "Minute-man", :classname => "badges-calendar", :id => 45 }

      ]

      BADGES_BY_ID = Hash[*BADGES.map { |badge| [badge[:id], badge] }.flatten] 
      BADGES_BY_CLASS = Hash[*BADGES.map { |badge| [badge[:classname], badge] }.flatten] 
    end
  end
end
