class ArticleBodyObserver < ActiveRecord::Observer

	observe Solution::ArticleBody, Solution::DraftBody

	def before_save(article_body)
		auto_create_hyperlink(article_body)
	end

	def auto_create_hyperlink(article_body)
		article_body.description = Rinku.auto_link(article_body.description, :urls, 'rel="noreferrer"')
	end
end 