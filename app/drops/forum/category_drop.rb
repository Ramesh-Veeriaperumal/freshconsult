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
    @forums ||= @source.forums.visible(User.current)
  end

  def total_forums
    @source.forums.visible(User.current).size
  end
  
end