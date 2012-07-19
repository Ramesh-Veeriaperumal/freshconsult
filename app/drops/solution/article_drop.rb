class Solution::ArticleDrop < BaseDrop
  
  include ActionController::UrlWriter
  
  liquid_attributes << :title << :status << :thumbs_up << :thumbs_down
  
  def initialize(source)
    super source
  end
  
  def body
    source.description
  end
  
  def body_plain
    source.desc_un_html
  end

  def modified_on
    source.updated_at.to_s(:long_day)
  end
  
  def id
    source.id
  end
  
  def url
    support_solutions_article_path(source)
  end
  
  def tags
    @tags ||= liquify(*@source.tags)
  end

  def attachments
    source.attachments
  end
  
  def type
    source.art_type
  end
  
  
end