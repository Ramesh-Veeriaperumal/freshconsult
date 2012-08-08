class Solution::FolderDrop < BaseDrop
  
  include ActionController::UrlWriter
  
  liquid_attributes << :name << :description << :visibility
  
  def initialize(source)
    super source
  end
  
  def id
    source.id
  end
  
  def url
    support_solutions_folder_path(source)
  end
  
  def solutions #To do.. Scoping.. current_user
    @solutions ||= liquify(*@source.articles)
  end
  
end