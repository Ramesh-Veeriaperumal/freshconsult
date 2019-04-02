module SolutionDraftsTestHelper

  def article_with_draft
    article_meta = create_article(article_params)
    @article = article_meta.primary_article
    @draft = @article.build_draft_from_article
    @draft.save!
  end

  def article_without_draft
    @article = @account.solution_articles.last
    @article.draft.destroy if @article.draft
    @article.reload
  end

  def autosave_pattern(draft)
    {
      timestamp: draft.updation_timestamp
    }
  end

end