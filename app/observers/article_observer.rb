require "solution/article"

class ArticleObserver < ActiveRecord::Observer

	observe Solution::Article

	include ProcessQuests
	
	def after_create(article)
		process_solutions_quest(article)
	end
	
end
