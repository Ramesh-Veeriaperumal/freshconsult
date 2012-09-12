module Gamification
	module Quests
		module ProcessTopicQuests

			def evaluate_topic_quests(topic)
				return if topic.user.customer?
				RAILS_DEFAULT_LOGGER.debug %(INSIDE evaluate_topic_quests)
				topic.user.available_quests.create_forum_quests.each do |quest|
					is_a_match = quest.matches(topic)
					if is_a_match and evaluate_query(quest,topic)
						quest.award!(topic.user)
					end
				end
			end

			def evaluate_query(quest, topic, end_time=Time.zone.now)
				conditions = quest.filter_query
				f_criteria = quest.time_condition(end_time)
				conditions[0] = conditions.empty? ? f_criteria : (conditions[0] + ' and ' + f_criteria)
				
				created_topics_in_time = quest_scoper(topic.account, topic.user).count(
					'topics.id', :conditions => conditions)
				
				quest_achieved = created_topics_in_time >= quest.quest_data[0][:value].to_i
			end

			def quest_scoper(account, user)
				account.topics.by_user(user)
			end

		end
	end
end