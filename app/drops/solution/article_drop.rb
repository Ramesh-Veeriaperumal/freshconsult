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
    source.updated_at
  end
  
  def created_on
    source.created_at
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
  
  def folder
    source.folder
  end

  def category
    source.folder.category
  end

  def thumbs_up_url
    thumbs_up_support_solutions_article_path(source.id)
  end
  
  def thumbs_down_url
    thumbs_down_support_solutions_article_path(source.id)
  end

  # !PORTALCSS CHECK need to check with shan 
  # if we can keep excerpts for individual model objects
  def excerpt_title
    source.excerpts.title
  end

  def excerpt_description
    source.excerpts.desc_un_html
  end

  # def feedback_form
  #   ActionView::Base.new(Rails::Configuration.new.view_path).render_to_string :partial => 
  # end
end