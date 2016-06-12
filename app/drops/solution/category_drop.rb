class Solution::CategoryDrop < BaseDrop
  
  include Rails.application.routes.url_helpers
  
  self.liquid_attributes += [:name, :description ]
  
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
 
end