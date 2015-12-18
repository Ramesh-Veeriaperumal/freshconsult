class Solution::DraftBinarizeObserver < ActiveRecord::Observer

	observe Solution::Draft

	def after_create(object)
		return unless multilingual
		update_draft(object, true)
	end

	def after_destroy(object)
		return unless multilingual
		update_draft(object, false)
	end

	private

		def multilingual
			Account.current.multilingual?
		end

		def update_draft(object, status)
			meta = object.article.solution_article_meta
			meta.send("#{object.article.language_key}_draft_present=", status)
			meta.save
		end
end