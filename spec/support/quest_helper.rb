module QuestHelper

    include Gamification::Quests::Constants

    SAMPLE_POINTS  = [200, 250, 300, 500 ]

    def create_ticket_quest(account, quest_data, filter_data = nil)
        filter_data_hash = filter_data ? filter_data : { :and_filters => [], :or_filters => [], :actual_data => [] }
        quest_span = quest_data[:date] || TIME_TYPE_BY_TOKEN[:any_time]
        badge_id = rand(1..45)
        quest = FactoryGirl.build(:quest, { 
                :name => Gamification::Quests::Badges::BADGES_BY_ID[badge_id][:name], 
                :description => "Resolve #{quest_data[:value]} tickets in #{QUEST_TIME_BY_KEY[quest_span.to_i]} with conditions - #{filter_data_hash[:actual_data]} ", 
                :category => GAME_TYPE_KEYS_BY_TOKEN[:ticket], 
                :active => true, 
                :points => SAMPLE_POINTS.sample,
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

    def create_article_quest(account, quest_data, filter_data = nil)
        filter_data_hash = filter_data ? filter_data : { :and_filters => [], :or_filters => [], :actual_data => [] }
        quest_span = quest_data[:date] || TIME_TYPE_BY_TOKEN[:any_time]
        badge_id = rand(1..45)
        quest = FactoryGirl.build(:quest, { 
                :name => Gamification::Quests::Badges::BADGES_BY_ID[badge_id][:name], 
                :description => "Create #{quest_data[:value]} knowledge base article in a span of #{QUEST_TIME_BY_KEY[quest_span.to_i]} with matching these conditions #{filter_data_hash[:actual_data]} and unlock the badge & bonus points.", 
                :category => GAME_TYPE_KEYS_BY_TOKEN[:solution], 
                :active => true, 
                :points => SAMPLE_POINTS.sample,
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

    def create_forum_quest(account, forum_type, quest_data, filter_data = nil)
        filter_data_hash = filter_data ? filter_data : { :and_filters => [], :or_filters => [], :actual_data => [] }
        quest_span = quest_data[:date] || TIME_TYPE_BY_TOKEN[:any_time]
        badge_id = rand(1..45)
        quest = FactoryGirl.build(:quest, { 
                :name => Gamification::Quests::Badges::BADGES_BY_ID[badge_id][:name], 
                :description => "#{forum_type} #{quest_data[:value]} forum posts in a span of #{QUEST_TIME_BY_KEY[quest_span.to_i]} and matching these conditions #{filter_data_hash[:actual_data]} and unlock the badge & bonus points.", 
                :category => GAME_TYPE_KEYS_BY_TOKEN[:forum], 
                :sub_category => FORUM_QUEST_MODE_BY_TOKEN["#{forum_type}".to_sym],
                :active => true, 
                :points => SAMPLE_POINTS.sample,
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