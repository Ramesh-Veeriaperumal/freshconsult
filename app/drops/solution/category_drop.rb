class Solution::CategoryDrop < BaseDrop
  
  include ActionController::UrlWriter
  
  liquid_attributes << :name
  
  def initialize(source)
    super source
  end
  
  def id
    source.id
  end
  
  def url
    solution_category_path(@source)
  end
  
  def folders
    @folders ||= liquify(*@source.folders.reject(&:is_default?))
  end
  
end