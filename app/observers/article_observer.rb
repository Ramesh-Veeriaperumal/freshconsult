require "solution/article"

class ArticleObserver < ActiveRecord::Observer

	observe Solution::Article
	include Gamification::GamificationUtil
	require 'nokogiri'

	SOLUTION_UPDATE_ATTRIBUTES = ["folder_id", "status", "thumbs_up"]

	def before_save(article)
		remove_script_tags(article)
		set_un_html_content(article)
		article_changes(article)
		article.seo_data ||= {}
	end

	def after_create(article) 
		create_activity(article)
	end

	def after_commit(article)
		return unless gamification_feature?(article.account)
		changed_filter_attributes = @article_changes.keys & SOLUTION_UPDATE_ATTRIBUTES
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

	def remove_tag response, tag
	    doc = Nokogiri::HTML.fragment(response)
	    node = doc.search(tag)
	    node.remove
	    doc.to_html
  	end

  	def remove_script_tags(article)
  		article.description = remove_tag(article.description, 'script') 
  	end

	def set_un_html_content(article)
      article.desc_un_html = (article.description.gsub(/<\/?[^>]*>/, "")).gsub(/&nbsp;/i,"") unless article.description.empty?
  end

  def article_changes(article)
  	@article_changes = article.changes.clone
  end

end
