class Solution::DraftBinarizeObserver < ActiveRecord::Observer

	observe Solution::Draft

	def after_create(object)
		return unless multilingual
		object.unpublishing = object.article.status_changed? && !object.article.published?
    # Set unpublishing so that version is not created more than once.
		update_draft(object, true)
	end

	def after_destroy(object)
		return unless multilingual
		update_draft(object, false)
	end

	private

		def multilingual
			Account.current.multilingual_available?
		end

  def update_draft(object, status)
    # Creating another reference for the object since model changes during unpublish event were not captured.
    meta = Account.current.solution_article_meta.find(object.article.solution_article_meta.id)
    meta.safe_send("#{object.article.language_key}_draft_present=", status)
    meta.save
  end
end
