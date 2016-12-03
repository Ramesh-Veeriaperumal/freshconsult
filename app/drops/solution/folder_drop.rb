class Solution::FolderDrop < BaseDrop
  
  include Rails.application.routes.url_helpers
  
  self.liquid_attributes += [:name , :description , :visibility]

  CACHE_METHODS = [:articles_count, :articles]

  def context=(current_context)    
    current_context['paginate_url'] = support_solutions_folder_path(source)
    
    super
  end
  
  def initialize(source)
    super source
  end
  
  def id
    source.id
  end
  
  def url
    support_solutions_folder_path(source)
  end
  
  def category
    source.solution_category_meta
  end

  def articles_count
    @articles_count ||= @source.solution_article_meta.published.size
  end

  def articles
    @articles ||= @source.solution_article_meta.published.filter(@per_page, @page)
  end

  def articles_count_from_cache
    @articles_count ||= @source.visible_articles_count
  end

  def articles_from_cache
    @articles ||= @source.visible_articles
  end

  include Solution::PortalCacheMethods

  protected

  def additional_check_for_cache_fetch(meth)
    source.instance_variable_defined?("@visible_#{meth}")
  end
end