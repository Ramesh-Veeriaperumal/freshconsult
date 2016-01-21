class Solution::FolderMetaDrop < Solution::FolderDrop

  def category
    source.solution_category_meta
  end

  def articles_count
    @articles_count ||= @source.solution_article_meta.published.size
  end

  def articles
    @articles ||= @source.solution_article_meta.published.filter(@per_page, @page)
  end

end
