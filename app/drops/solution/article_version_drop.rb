# Any article object accessed in any portal page will be Solution::ArticleMeta object.
# The drop for Solution::ArticleMeta is Solution::ArticleDrop.
# Only page where we have Solution::Article object is support/search/show.portal.
# This drop methods will be used in support/search/show.portal page. We have overridden the necessary methods here.
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