class Solution::ArticleDrop < BaseDrop
  
  include Rails.application.routes.url_helpers
  
  self.liquid_attributes += [:title , :status]
  
  def initialize(source)
    super source
  end
  
  def title
    source.title
  end
  
  def status
    source.status
  end
  
  def body
    source.description
  end
  
  def body_plain
    source.desc_un_html
  end

  def modified_on
    source.modified_at
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
    source[:current_attachments] || source.attachments
  end

  def cloud_files
    source[:current_cloud_files] || source.cloud_files
  end
  
  def type
    source.art_type
  end
  
  def folder
    source.solution_folder_meta
  end

  def category
    source.solution_folder_meta.solution_category_meta
  end
  
  def thumbs_up
    source.current_child_thumbs_up
  end
  
  def thumbs_down
    source.current_child_thumbs_down
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

  # Note:
  # Couldnt find any internal uses
  # Will hit old search if used
  #
  def related_articles
    source.related(@portal.source).compact
  end

  def voted_by_user?
    source.voted_by_user? portal_user
  end

  def user
    source.user
  end

  def author
    source.user.name
  end

  def personalized_articles?
    @portal.personalized_articles?
  end

  # def feedback_form
  #   ActionView::Base.new(Rails::Configuration.new.view_path).render_to_string :partial => 
  # end
end