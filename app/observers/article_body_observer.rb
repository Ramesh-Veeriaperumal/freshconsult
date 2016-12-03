class ArticleBodyObserver < ActiveRecord::Observer

	observe Solution::ArticleBody, Solution::DraftBody

	def before_save(article_body)
		auto_create_hyperlink(article_body)
	end

	def auto_create_hyperlink(article_body)
		article_body.description = FDRinku.auto_link(article_body.description, { :attr => 'rel="noreferrer"' })
	end
end 