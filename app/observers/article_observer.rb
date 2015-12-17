class ArticleObserver < ActiveRecord::Observer

	observe Solution::Article
	require 'nokogiri'

	def before_save(article)
		remove_script_tags(article)
		set_un_html_content(article)
		set_art_type(article)
		modified_date(article) if (article.article_body.changed? or article.title_changed?)
		article.article_changes
		create_draft_for_article(article)
		article.seo_data ||= {}
	end

	def before_destroy(article)
	    create_activity(article, 'delete_article')
	end

	def after_create(article) 
		create_activity(article, 'new_article')
	end

	def after_update(article)
		create_activity(article, 'published_article') if article.published? and article.status_changed?
		create_activity(article, 'unpublished_article') if !article.published? and article.status_changed?
	end

private

 	def create_activity(article, type)
		article.activities.create(
			:description => "activities.solutions.#{type}.long",
			:short_descr => "activities.solutions.#{type}.short",
			:account 		=> article.account,
			:user 			=> User.current,
			:activity_data 	=> {
									:path => Rails.application.routes.url_helpers.solution_article_path(article.id),
								 	:url_params => {
												 		:id => article.id,
												 		:path_generator => 'solution_article_path'
													},
								 	:title => article.to_s
								}
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

    def create_draft_for_article(article)
    	return unless article.status_changed? && article.status == Solution::Article::STATUS_KEYS_BY_TOKEN[:draft] && !article.draft
			article.build_draft(article.draft_attributes)
			article.draft.user_id = article.user_id
			article.draft.populate_defaults
    end

    def set_art_type(article)
			article.art_type ||= Solution::Article::TYPE_KEYS_BY_TOKEN[:permanent]
  	end
end
