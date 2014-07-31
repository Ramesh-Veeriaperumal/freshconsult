class Solution::CategoryDrop < BaseDrop
  
  include Rails.application.routes.url_helpers
  
  liquid_attributes << :name << :description
  
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
    @folders_count ||= @source.folders.visible(portal_user).size
  end

  def folders
    @folders ||= @source.folders.visible(portal_user)
  end
 
end