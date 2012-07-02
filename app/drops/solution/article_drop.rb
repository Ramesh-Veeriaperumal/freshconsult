class Solution::ArticleDrop < BaseDrop
  
  include ActionController::UrlWriter
  
  liquid_attributes << :title << :status
  
  def initialize(source)
    super source
  end
  
  def body
    source.description
  end
  
  def body_plain
    source.desc_un_html
  end
  
  def id
    source.id
  end
  
  def url
    solution_category_folder_article_path(source.folder.category, source.folder, source)
  end
  
  def tags
    @tags ||= liquify(*@source.tags)
  end
  
  def type
    source.art_type
  end
  
  
end