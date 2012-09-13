module Gamification
  module Quests
    module Seed
      include Gamification::Quests::Constants
      include Gamification::Quests::Badges
      
      DEFAULT_DATA = [
        { 
          :name => 'Show them you can write!', 
          :description => 'Publish 10 solution articles with more than 50 customer likes and unlock the "Best Seller" Badge and earn 500 Bonus points!', 
          :category => GAME_TYPE_KEYS_BY_TOKEN[:solution], 
          :active => true, 
          :points => 500,
          :badge_id => BADGES_BY_CLASS["badges-open-book"][:id],
          :filter_data => { 
              :and_filters => [
                  { :name => "thumbs_up", :operator => "greater_than", :value => "50" }
                ],
              :or_filters => {},
              :actual_data => [
                  { :name => "thumbs_up", :operator => "greater_than", :value => "50" }
              ]
            },
          :quest_data => [{
              :value => "10",
              :date => TIME_TYPE_BY_TOKEN[:any_time]
            }]
        },
        { 
          :name => 'Engage the Community!', 
          :description => 'Participate in 50 Community forum discussions in 2 weeks to unlock the "Super Commentor" Badge and earn 300 Bonus Points!', 
          :category => GAME_TYPE_KEYS_BY_TOKEN[:forum], 
          :sub_category => FORUM_QUEST_MODE_BY_TOKEN[:answer], 
          :active => true, 
          :points => 300,
          :badge_id => BADGES_BY_CLASS["badges-forum-comment"][:id],
          :filter_data => { 
              :and_filters => [],
              :or_filters => {},
              :actual_data => []
            },
          :quest_data => [{
              :value => "50",
              :date => TIME_TYPE_BY_TOKEN[:two_weeks]
            }]
        },
        { 
          :name => 'Be a Knowledge Guru!', 
          :description => 'Publish 15 Solution articles in a month to unlock the "Super Writer" Badge and earn 500 Bonus Points', 
          :category => GAME_TYPE_KEYS_BY_TOKEN[:solution], 
          :active => true, 
          :points => 500,
          :badge_id => BADGES_BY_CLASS["badges-scribe"][:id],
          :filter_data => { 
              :and_filters => [],
              :or_filters => {},
              :actual_data => []
            },
          :quest_data => [{
              :value => "15",
              :date => TIME_TYPE_BY_TOKEN[:one_month]
            }]
        },
        { 
          :name => 'Go Social!', 
          :description => 'Resolve 25 tickets from Twitter or Facebook in a week to unlock the "Social Supporter" Badge and win 150 Bonus points', 
          :category => GAME_TYPE_KEYS_BY_TOKEN[:ticket], 
          :active => true, 
          :points => 150,
          :badge_id => BADGES_BY_CLASS["badges-fb"][:id],
          :filter_data => { 
              :and_filters => [],
              :or_filters => {
                "source" => [
                    { :name => "source", :operator => "is", :value => "5" },
                    { :name => "source", :operator => "is", :value => "6" }
                ]
              },
              :actual_data => [
                  { :name => "source", :operator => "is", :value => "5" },
                  { :name => "source", :operator => "is", :value => "6" }
              ]
            },
          :quest_data => [{
              :value => "25",
              :date => TIME_TYPE_BY_TOKEN[:one_week]
            }]
        },
        { 
          :name => 'Participate in Forums!', 
          :description => 'Answer 10 forum posts in a week to unlock the "Commentor" Badge and earn 200 Bonus points!', 
          :category => GAME_TYPE_KEYS_BY_TOKEN[:forum], 
          :sub_category => FORUM_QUEST_MODE_BY_TOKEN[:answer],
          :active => true, 
          :points => 200,
          :badge_id => BADGES_BY_CLASS["badges-forum"][:id],
          :filter_data => { 
              :and_filters => [],
              :or_filters => {},
              :actual_data => []
            },
          :quest_data => [{
              :value => "10",
              :date => TIME_TYPE_BY_TOKEN[:one_week]
            }]
        },
        { 
          :name => 'Share Knowledge!', 
          :description => 'Publish 5 Solution articles in a week to unlock the "Writer" badge and win 250 Bonus points!', 
          :category => GAME_TYPE_KEYS_BY_TOKEN[:solution], 
          :active => true, 
          :points => 250,
          :badge_id => BADGES_BY_CLASS["badges-writer"][:id],
          :filter_data => { 
              :and_filters => [],
              :or_filters => {},
              :actual_data => []
            },
          :quest_data => [{
              :value => "5",
              :date => TIME_TYPE_BY_TOKEN[:one_week]
            }]
        },
        { 
          :name => 'Earn Customer Love!', 
          :description => 'Resolve 10 tickets in a week with Customer Satisfaction rating of Awesome and unlock the "Heart" badge and get 200 Bonus points!', 
          :category => GAME_TYPE_KEYS_BY_TOKEN[:ticket], 
          :active => true, 
          :points => 200,
          :badge_id => BADGES_BY_CLASS["badges-love"][:id],
          :filter_data => { 
              :and_filters => [
                  { :name => "st_survey_rating", :operator => "is", :value => "happy" }
              ],
              :or_filters => {},
              :actual_data => [
                  { :name => "st_survey_rating", :operator => "is", :value => "happy" }
              ]
            },
          :quest_data => [{
              :value => "10",
              :date => TIME_TYPE_BY_TOKEN[:one_week]
            }]
        }        
      ]
    end
  end
end