class Forum::CategoryDrop < BaseDrop
  
  include ActionController::UrlWriter
  
  liquid_attributes << :name << :description
  
  def initialize(source)
    super source
  end
  
  def id
    source.id
  end
  
  def url
    category_path(@source)
  end
  
  def forums
    @forums ||= liquify(*@source.forums)
  end
  
end