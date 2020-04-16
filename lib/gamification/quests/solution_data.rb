module Gamification
	module Quests
		class SolutionData

			def initialize(args)
				args.symbolize_keys!
				@article = Account.current.solution_articles.find(args[:id])
			end

			def evaluate_solution_quests
				return unless @article.blank? || @article.published?

				@article.user.available_quests.solution_quests.each do |quest|
					is_a_match = quest.matches(@article)
					if is_a_match and evaluate_query(quest,@article)
						quest.award!(@article.user)
					end
				end
			end

			def evaluate_query(quest, article, end_time=Time.zone.now)
				conditions = quest.filter_query
				f_criteria = quest.time_condition(end_time)
				conditions[0] = conditions.empty? ? f_criteria : (conditions[0] + ' and ' + f_criteria)

				created_solns_in_time = quest_scoper(article.account, article.user).where(conditions).count('solution_articles.id')
				quest_achieved = created_solns_in_time >= quest.quest_data[0][:value].to_i
			end

			def quest_scoper(account, user)
				account.solution_articles.visible.by_user(user).joins(:solution_article_meta)
			end
		end
	end
end