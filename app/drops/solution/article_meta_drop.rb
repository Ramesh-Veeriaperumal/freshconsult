class Solution::ArticleMetaDrop < Solution::ArticleDrop

  def folder
    source.solution_folder_meta
  end

  def category
    source.solution_folder_meta.solution_category_meta
  end

end
