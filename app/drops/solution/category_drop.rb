class Solution::CategoryDrop < BaseDrop
  
  include Rails.application.routes.url_helpers
  
  self.liquid_attributes += [:name, :description ]

  CACHE_METHODS = [:folders_count, :folders]
  
  def initialize(source)
    super source
  end
  
  def id
    source.id
  end
  
  def url
    support_solution_path(@source)
  end
  
  def folders_count
    @folders_count ||= @source.solution_folder_meta.visible(portal_user).size
  end

  def folders
    @folders ||= @source.solution_folder_meta.visible(portal_user)
  end

  def folders_count_from_cache
    @folders_count ||= @source.visible_folders_count
  end

  def folders_from_cache
    @folders ||= @source.visible_folders
  end
 
  include Solution::PortalCacheMethods

  protected

  def additional_check_for_cache_fetch(meth)
    source.instance_variable_defined?("@visible_#{meth}")
  end
end