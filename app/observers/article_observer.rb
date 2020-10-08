class ArticleObserver < ActiveRecord::Observer
  include Solution::ArticleVersioning
	observe Solution::Article
	require 'nokogiri'

	def before_save(article)
		set_un_html_content(article) if article.article_body.changed?
		article.article_changes
    create_draft_for_article(article)
    unpublishing = only_status_changed?(article) && !article.published?
    article.clear_approvals if unpublishing && Account.current.article_approval_workflow_enabled?
		article.seo_data ||= {}
      # article body change is captured only here
      if content_changed?(article) || article.status_changed? || (article.draft && article.draft.publishing) || article.attachment_added
        modify_date_and_author(article)
        return unless article.account.article_versioning_enabled?

        # When i directly unpublish, versions should be marked unlive
        article.unpublishing = unpublishing
        # When "Published : edit + autosave and Unpublish" draft observer will not be triggered, so sending draft for versioning
        can_version_draft = article.draft && !article.draft.new_record? && article.unpublishing && !article.draft.unpublishing
        can_version_article = article.draft ? (!article.draft.new_record? && (!article.draft.unpublishing || article.draft.publishing)) : true
        # When unpublish is done on an article that is published and does not have a draft, version creation should not happen here. Draft observer will take care of it.
        # Also, when a published article(without draft) is published again without an autosave, draft obj check is necessary. New version needs to be created.
        if !article.new_record? # Avoid version creation twice
          # Flush article and version votes on article publish
          article.flush_hits! if (article.draft && article.draft.publishing) || (!article.status_changed? && article.published?)
          if can_version_draft
            article.version_through = :draft
          elsif can_version_article
            article.version_through = :article
          end
        elsif article.published?
          # For new record, if the article is directly published (without autosave or save) we can create version
          article.version_through = :article
        end
      end
	end

  # only in after save callback ids for article record and cloud files are generated. but after save the model will be in clean state ({attr}_changed? will be false for everything). 
  # Thus set flag in before_save and handle version creation in after_save
  def after_save(article)
    if article.version_through == :draft
      article.draft.session = article.session
      version_create_or_update(article.draft)
    elsif article.version_through == :article
      version_create_or_update(article)
    end
    article.version_through = nil
  end

	def after_update(article)
		article.create_activity('published_article') if article.published? and article.status_changed?
		article.create_activity('unpublished_article') if !article.published? and article.status_changed?
		enqueue_article_for_kbase_check(article)
	end

  def before_validation(article)
    set_default_status(article)
  end

  def after_create(article)
  	enqueue_article_for_kbase_check(article)
  end

private

		def set_un_html_content(article)
			article.desc_un_html = UnicodeSanitizer.remove_4byte_chars(Helpdesk::HTMLSanitizer.plain(article.description)) unless article.description.empty?
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
        draft.safe_send("#{k}=", v)
      end
			article.draft.populate_defaults
    end

    def enqueue_article_for_kbase_check(article)
      if !article.account.kbase_spam_whitelist_enabled? && ((article.account.created_at >= (Time.zone.now - 90.days)) || (article.account.subscription.present? && article.account.subscription.free?))
				Rails.logger.debug "Comes inside enqueue_article_for_kbase_check loop for account : #{article.account} and article #{article.id}"
				Solution::CheckContentForSpam.perform_async({:article_id => article.id})
			end
    end

    def content_changed?(article)
      article.title_changed? || article.article_body.changed?
    end

    def only_status_changed?(article)
      article.status_changed? && !content_changed?(article)
    end
end

