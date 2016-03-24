class Solution::ArticleVersionDrop < Solution::ArticleDrop
  
  include Rails.application.routes.url_helpers

  def id
    source.parent_id
  end

  def type
    source.solution_article_meta.art_type
  end
  
  def thumbs_up
    source.thumbs_up
  end
  
  def thumbs_down
    source.thumbs_down
  end

  def thumbs_up_url
    thumbs_up_support_solutions_article_path(source.parent_id)
  end
  
  def thumbs_down_url
    thumbs_down_support_solutions_article_path(source.parent_id)
  end

end