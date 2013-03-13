class Solution::FolderDrop < BaseDrop
  
  include ActionController::UrlWriter
  
  liquid_attributes << :name << :description << :visibility

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
    source.category
  end
  
  def articles_count
    @articles_count ||= @source.published_articles.size
  end
  
  def articles
    @articles ||= @source.published_articles.filter(@per_page, @page)
  end 
  
end