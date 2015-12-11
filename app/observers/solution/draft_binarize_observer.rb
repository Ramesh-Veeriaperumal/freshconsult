class Solution::DraftBinarizeObserver < ActiveRecord::Observer

	observe Solution::Draft

	def after_create(object)
		update_draft(object, true)
	end

	def after_destroy(object)
		update_draft(object, false)
	end

	private

		def update_draft(object, status)
			meta = object.article.solution_article_meta
			meta.send("#{object.article.language_key}_draft=", status)
			meta.save
		end
end