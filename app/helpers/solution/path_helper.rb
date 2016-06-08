module Solution::PathHelper

	def multilingual_article_path(article, options={})
		current_account.multilingual? ?
		solution_article_version_path(article, options.slice(:anchor).merge({:language => article.language.code})) :
		solution_article_path(article, options.slice(:anchor))
	end
end