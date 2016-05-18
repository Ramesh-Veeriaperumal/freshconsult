class ArticleObserver < ActiveRecord::Observer

	observe Solution::Article
	require 'nokogiri'

	def before_save(article)
		remove_script_tags(article)
		set_un_html_content(article)
		modify_date_and_author(article) if (article.article_body.changed? || article.title_changed?)
		article.article_changes
		create_draft_for_article(article)
		article.seo_data ||= {}
	end

	def after_update(article)
		article.create_activity('published_article') if article.published? and article.status_changed?
		article.create_activity('unpublished_article') if !article.published? and article.status_changed?
	end

  def before_validation(article)
    set_default_status(article)
  end

private

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

    def modify_date_and_author(article)
      article.modified_at = Time.now.utc
      article.modified_by = article.new_record? ? article.user_id : User.current.id
    end

    def handle_meta_likes(article)
			changed_attribs = article.changes.slice(*Solution::Article::VOTE_TYPES)
			article_meta = article.solution_article_meta
			changed_attribs.each do |attrib, changes|
				article_meta.increment(attrib, changes[1] - changes[0])
			end
    end

    def set_default_status(article)
      article.status ||= Solution::Article::STATUS_KEYS_BY_TOKEN[:published]
    end

    def create_draft_for_article(article)
    	return unless article.status_changed? && article.status == Solution::Article::STATUS_KEYS_BY_TOKEN[:draft] && !article.draft
			draft = article.build_draft
      article.draft_attributes(:user_id => article.user_id).each do |k, v|
        draft.send("#{k}=", v)
      end
			article.draft.populate_defaults
    end
end
