require "solution/article"

class ArticleObserver < ActiveRecord::Observer

	observe Solution::Article

	include Gamification::Quests::ProcessSolutionQuests

	SOLUTION_UPDATE_ATTRIBUTES = ["folder_id", "status", "thumbs_up"]

	def after_create(article) 
		evaluate_solution_quests(article)
	end

	def after_update(article)
		changed_filter_attributes = article.changed & SOLUTION_UPDATE_ATTRIBUTES
		evaluate_solution_quests(article) if changed_filter_attributes.any?
	end
	
end
