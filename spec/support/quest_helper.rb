module QuestHelper
  include Gamification::Quests::Constants
  SAMPLE_POINTS  = [200, 250, 300, 500 ]
  
  def create_ticket_quest(account, quest_data, filter_data = nil)
    filter_data_hash = filter_data ? filter_data : { :and_filters => [], :or_filters => [], :actual_data => [] }
    quest_span = quest_data[:date] || TIME_TYPE_BY_TOKEN[:any_time]
    badge_id = rand(1..45)
    quest = Factory.build(:quest, { 
            :name => Gamification::Quests::Badges::BADGES_BY_ID[badge_id][:name], 
            :description => "Resolve #{quest_data[:value]} tickets in #{quest_span} span ", 
            :category => GAME_TYPE_KEYS_BY_TOKEN[:ticket], 
            :active => true, 
            :points => SAMPLE_POINTS[rand(0..3)],
            :badge_id => Gamification::Quests::Badges::BADGES_BY_ID[badge_id][:id],
            :filter_data => filter_data_hash,
            :quest_data => [{
                :value => quest_data[:value],
                :date => quest_span
            }],
            :account_id => account.id
          })
    quest.save
    quest
  end
end