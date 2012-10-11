module Gamification
	module Quests
		class ProcessSolutionQuests < Resque::FreshdeskBase
			@queue = "gamificationQueue"

			def self.perform(args)
				args.symbolize_keys!
				id, account_id = args[:id], args[:account_id]
				article = Solution::Article.find_by_id_and_account_id(id, account_id)
				evaluate_solution_quests(article) unless article.blank?
			end

			def self.evaluate_solution_quests(article)
				return unless article.published?

				article.user.available_quests.solution_quests.each do |quest|
					is_a_match = quest.matches(article)
					if is_a_match and evaluate_query(quest,article)
						quest.award!(article.user)
					end
				end
			end

			def self.evaluate_query(quest, article, end_time=Time.zone.now)
				conditions = quest.filter_query
				f_criteria = quest.time_condition(end_time)
				conditions[0] = conditions.empty? ? f_criteria : (conditions[0] + ' and ' + f_criteria)

				created_solns_in_time = quest_scoper(article.account, article.user).count(
					'solution_articles.id', :conditions => conditions)
				quest_achieved = created_solns_in_time >= quest.quest_data[0][:value].to_i
			end

			def self.quest_scoper(account, user)
				account.solution_articles.visible.by_user(user)
			end

		end
	end
end
