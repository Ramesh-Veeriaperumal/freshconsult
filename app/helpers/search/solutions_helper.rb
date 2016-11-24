module Search::SolutionsHelper

  def format_articles_result
    @search_results.compact.map do |article|
      article_response_params(article) unless !can_insert_link?(article, article_url(article)) && @ticket.microresponse_only?
    end.reject(&:blank?)
  end

  def article_url(article)
    url_opts = @ticket.article_url_options(article)
    url_opts.merge!({ url_locale: article.language.code }) if current_account.multilingual?
    url_opts[:host].present? && support_solutions_article_url(article, url_opts)
  end


  def article_response_params(article)
    {
      id: article.id,
      title: article.title,
      published: article.published?,
      visible: article.solution_folder_meta.visible?(current_user),
      url: article_url(article),
      insert_link: can_insert_link?(article, article_url(article)),
      insert_content: !@ticket.microresponse_only?
    }
  end

  def can_insert_link?(article, link)
    link && article.solution_folder_meta.visible?(@ticket.requester) && article.published?
  end

end