module Gamification
	module Quests
		module ProcessSolutionQuests

			def evaluate_solution_quests(article)
				return unless article.published?

				article.user.available_quests.solution_quests.each do |quest|
					is_a_match = quest.matches(article)
					if is_a_match and evaluate_query(quest,article)
						quest.award!(article.user)
					end
				end
			end

			def evaluate_query(quest, article, end_time=Time.zone.now)
				conditions = quest.filter_query
				f_criteria = quest.time_condition(end_time) + 
					' and solution_articles.user_id = '+article.user.id.to_s
				conditions[0] = conditions.empty? ? f_criteria : (conditions[0] + ' and ' + f_criteria)

				created_solns_in_time = quest_scoper(article.account).count(
					'solution_articles.id', :conditions => conditions)
				quest_achieved = created_solns_in_time >= quest.quest_data[0][:value].to_i
			end

			def quest_scoper(account)
				account.solution_articles.visible
			end

		end
	end
end
