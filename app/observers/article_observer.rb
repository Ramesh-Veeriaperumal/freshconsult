require "solution/article"

class ArticleObserver < ActiveRecord::Observer

	observe Solution::Article
	include Gamification::GamificationUtil

	SOLUTION_UPDATE_ATTRIBUTES = ["folder_id", "status", "thumbs_up"]

	def before_save(article)
		set_un_html_content(article)
	end

	def after_create(article) 
		create_activity(article)
		add_resque_job(article) if gamification_feature?(article.account)
	end

	def after_update(article)
		return unless gamification_feature?(article.account)
		changed_filter_attributes = article.changed & SOLUTION_UPDATE_ATTRIBUTES
		add_resque_job(article) if changed_filter_attributes.any?
	end

	def add_resque_job(article)
		return unless article.published?
		Resque.enqueue(Gamification::Quests::ProcessSolutionQuests, { :id => article.id, 
			:account_id => article.account_id })
	end

private

	def create_activity(article)
      article.activities.create(
        :description => 'activities.solutions.new_solution.long',
        :short_descr => 'activities.solutions.new_solution.short',
        :account => article.account,
        :user => article.user,
        :activity_data => {}
      )
  end

	def set_un_html_content(article)
      article.desc_un_html = (article.description.gsub(/<\/?[^>]*>/, "")).gsub(/&nbsp;/i,"") unless article.description.empty?
  end
	
end
