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
    support_discussions_path
  end
  
  def forums
    @forums ||= liquify(*@source.portal_forums)
  end
  
end