require "solution/article"

class ArticleObserver < ActiveRecord::Observer

	observe Solution::Article

	include Gamification::Quests::ProcessSolutionQuests
	include Gamification::GamificationUtil

	SOLUTION_UPDATE_ATTRIBUTES = ["folder_id", "status", "thumbs_up"]

	def after_create(article) 
		evaluate_solution_quests(article) if gamification_feature?(article.account)
	end

	def after_update(article)
		return unless gamification_feature?(article.account)
		changed_filter_attributes = article.changed & SOLUTION_UPDATE_ATTRIBUTES
		evaluate_solution_quests(article) if changed_filter_attributes.any?
	end
	
end
