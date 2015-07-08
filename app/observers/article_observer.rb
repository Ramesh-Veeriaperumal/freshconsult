class ArticleObserver < ActiveRecord::Observer

	observe Solution::Article
	require 'nokogiri'


	def before_save(article)
		remove_script_tags(article)
		set_un_html_content(article)
		modified_date(article) if (article.article_body.changed? or article.title_changed?)
		handle_meta_likes(article) if (article.solution_article_meta && (article.thumbs_up_changed? or article.thumbs_down_changed?))
		article.article_changes
		article.seo_data ||= {}
	end

	def after_create(article) 
		create_activity(article)
		article.account.clear_solution_categories_from_cache
	end
	
	def after_destroy(article)
		article.account.clear_solution_categories_from_cache
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
	    doc = Nokogiri::HTML.parse(response)
	    node = doc.search(tag)
	    node.remove
	    doc.css('body').inner_html
  	end

  	def remove_script_tags(article)
  		description = remove_tag(article.description, 'script') 
  		article.description = description
  	end

		def set_un_html_content(article)
			article.desc_un_html = Helpdesk::HTMLSanitizer.plain(article.description) unless article.description.empty?
    end

    def modified_date(article)
      article.modified_at = Time.now.utc
    end

    def handle_meta_likes(article)
		changed_attribs = article.changes.slice(*Solution::Article::VOTE_TYPES)
		article_meta = article.solution_article_meta
		changed_attribs.each do |attrib, changes|
			article_meta.increment(attrib, changes[1] - changes[0])
		end
    end
end
